#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>
#include <ArduinoJson.h>

// --- LIBRARIES FOR OLED AND KEYPAD ---
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Keypad.h>
#include <Preferences.h>

/* * ---------------------------------------------------------------------------------------
 * CONFIGURATION
 * ---------------------------------------------------------------------------------------
 */
// --- DEFAULT FALLBACKS (Used if NVS is empty) ---
#define DEFAULT_WIFI_SSID       "LettuVault-01"
#define DEFAULT_WIFI_PASSWORD   "Aa1231325213!"
#define DEFAULT_MQTT_SERVER     "10.42.0.1"
#define DEFAULT_MQTT_PORT       1883
#define DEVICE_ID               "ESP32-LettuVault-01"
#define API_KEY                 "lettuce-master-key-2024" 

// --- DYNAMIC NETWORK SETTINGS ---
String wifi_ssid;
String wifi_password;
String mqtt_server_host;
int mqtt_server_port;

const char* topic_sensors = "lettuvault/sensors";
const char* topic_control = "lettuvault/control"; 
const char* topic_config_sync = "lettuvault/config/sync";

/* * HARDWARE PINS & SETUP
 * ---------------------------------------------------------------------------------------
 */
// --- RELAY PINS (Single ESP32 -> Two 4-Channel Relay Boards) ---
#define RELAY_COMPRESSOR 25 // Board 1 - IN1 (30A)
#define RELAY_VACUUM     26 // Board 2 - IN1 (10A)
#define RELAY_HUMIDIFIER 27 // Board 2 - IN2 (10A)

// --- OLED Display Setup (I2C Bus 0 - Wire: SDA=21, SCL=22) ---
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1 
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// --- BME280 Setup (Standard I2C Bus - Wire) ---
// Using default Wire pins (SDA=21, SCL=22) shared with OLED
bool isDisplayFound = false;

// --- Keypad Setup ---
const byte ROWS = 4; 
const byte COLS = 4; 

char keys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};

byte rowPins[ROWS] = {19, 18, 5, 4}; 
byte colPins[COLS] = {13, 14, 23, 15}; 

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// --- PREFERENCES FOR NETWORKING ---
Preferences preferences;

// --- AMNESIAC TARGET SETTINGS (Default values on boot) ---
float set_temperature = 25.0;
float set_humidity = 60.0;
float set_pressure = 1200.0;

// --- MENU STATE MACHINE ---
enum MenuPage {
    PAGE_HOME,
    PAGE_SYS_CONFIG,
    PAGE_EDIT_CONFIG,
    PAGE_NEW_VAL,
    PAGE_SYS_READ,
    PAGE_NET_CONFIG,
    PAGE_WIFI_STAT,
    PAGE_CHG_WIFI_SSID,
    PAGE_CHG_WIFI_PASS,
    PAGE_MQTT_STAT,
    PAGE_CHG_MQTT_SERV,
    PAGE_CHG_MQTT_PORT
};

MenuPage currentPage = PAGE_HOME;
String inputBuffer = "";
int subPageMode = 0; // 0: Temp, 1: Hum, 2: Pres
float currentSensorTemp = 0, currentSensorHum = 0, currentSensorPres = 0;

// --- HARDWARE SAFETY & STATE VARIABLES ---
unsigned long lastCompressorOffTime = 0;
unsigned long lastVacuumOffTime     = 0;
unsigned long lastHumidifierOffTime = 0;
bool isCompressorRunning = false;
bool isVacuumRunning = false;
bool isHumidifierRunning = false;
const unsigned long RELAY_LOCKOUT_MS = 300000; // 5 minutes — prevents rapid cycling

// --- RTOS & Object Setup ---
Adafruit_BME280 bme;
WiFiClient espClient;
PubSubClient client(espClient);

unsigned long lastMsg = 0;
const unsigned long SENSOR_READ_INTERVAL_MS = 10000; // Interval for reading sensors and sending data (5 seconds)
SemaphoreHandle_t mqttMutex; 
TaskHandle_t NetworkTaskHandle;

// --- STATE TRACKING FOR MULTI-CORE SAFE OLED UPDATES ---
volatile bool wifiState = false;
volatile bool mqttState = false;
bool lastWifiState = false;
bool lastMqttState = false;
bool forceDisplayUpdate = true; 

volatile bool sendAckPending = false;
String pendingAckId = "";

/*
 * HELPER FUNCTION: UPDATE OLED DISPLAY
 */
void updateDisplay() {
    if (!isDisplayFound) return;
    display.clearDisplay();
    display.setCursor(0, 0);
    display.setTextSize(1);

    switch (currentPage) {
        case PAGE_HOME:
            display.print("WIFI:"); display.print(wifiState ? "OK" : "NO");
            display.print(" | MQTT:"); display.println(mqttState ? "OK" : "NO");
            display.println(F("1. System Config"));
            display.println(F("2. System Read"));
            display.println(F("3. Network Config"));
            break;

        case PAGE_SYS_CONFIG:
            display.println(F("System Config"));
            display.printf("Set Temperature: %.1f\n", set_temperature);
            display.printf("Set Humidity: %.1f\n", set_humidity);
            display.printf("Set Pressure: %.1f\n", set_pressure);
            display.println(F("\n*-Edit Config D-Back"));
            break;

        case PAGE_EDIT_CONFIG:
            display.println(F("Edit Config"));
            display.println(F("1. Temperature"));
            display.println(F("2. Humidity"));
            display.println(F("3. Pressure"));
            display.println(F("D-Back"));
            break;

        case PAGE_NEW_VAL:
            if (subPageMode == 0) display.println(F("New temperature:"));
            else if (subPageMode == 1) display.println(F("New humidity:"));
            else if (subPageMode == 2) display.println(F("New pressure:"));
            display.println(inputBuffer);
            display.println(F("\nA-Enter  D-Back"));
            break;

        case PAGE_SYS_READ:
            display.println(F("System Read"));
            display.printf("Temperature: %.1f\n", currentSensorTemp);
            display.printf("Humidity: %.1f\n", currentSensorHum);
            display.printf("Pressure: %.1f\n", currentSensorPres);
            display.println(F("D-Back"));
            break;

        case PAGE_NET_CONFIG:
            display.println(F("Network Config"));
            display.println(F("1. WIFI Status"));
            display.println(F("2. Change WIFI"));
            display.println(F("3. MQTT Status"));
            display.println(F("4. Change MQTT"));
            display.println(F("D-Back"));
            break;

        case PAGE_WIFI_STAT:
            display.println(F("WIFI Status"));
            display.printf("Status: %s\n", wifiState ? "Connected" : "Disconnected");
            display.printf("SSID: %s\n", wifi_ssid.c_str());
            display.println(F("\nD-Back"));
            break;

        case PAGE_CHG_WIFI_SSID:
            display.println(F("New WIFI SSID:"));
            display.println(inputBuffer);
            display.println(F("\nA-Enter  D-Back"));
            break;

        case PAGE_CHG_WIFI_PASS:
            display.println(F("New WIFI Pass:"));
            display.println(inputBuffer);
            display.println(F("\nA-Enter  D-Back"));
            break;

        case PAGE_MQTT_STAT:
            display.println(F("MQTT Status"));
            display.printf("State: %s\n", mqttState ? "CONNECTED" : "DISCONN");
            display.printf("Server: %s\n", mqtt_server_host.c_str());
            display.printf("Port: %d\n", mqtt_server_port);
            display.println(F("\nD-Back"));
            break;

        case PAGE_CHG_MQTT_SERV:
            display.println(F("New MQTT Server:"));
            display.println(inputBuffer);
            display.println(F("\nA-Enter  D-Back"));
            break;

        case PAGE_CHG_MQTT_PORT:
            display.println(F("New MQTT Port:"));
            display.println(inputBuffer);
            display.println(F("\nA-Enter  D-Back"));
            break;
    }

    display.display();
}

/*
 * CALLBACK FUNCTION
 */
void callback(char* topic, byte* payload, unsigned int length) {
    String message;
    for (int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    Serial.printf("Message arrived [%s] %s\n", topic, message.c_str());

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, message);

    if (!error) {
        bool changed = false;
        
        if (!doc["tx_id"].isNull()) {
            pendingAckId = doc["tx_id"].as<String>();
            sendAckPending = true; 
        }

        if (!doc["temperature"].isNull()) {
            float new_temp = doc["temperature"].as<float>();
            if (set_temperature != new_temp) {
                lastCompressorOffTime = millis() - RELAY_LOCKOUT_MS; 
                Serial.printf("[HVAC] Target temp changed to %.1f. Lockout bypassed.\n", new_temp);
            }
            set_temperature = new_temp;
            changed = true;
        }
        if (!doc["humidity"].isNull()) {
            set_humidity = doc["humidity"].as<float>();
            changed = true;
        }
        if (!doc["pressure"].isNull()) {
            set_pressure = doc["pressure"].as<float>();
            changed = true;
        }
        
        if (changed) {
            forceDisplayUpdate = true;
        }
    }
}

/*
 * CORE 0: NETWORK TASK 
 */
void networkTask(void * parameter) {
    for(;;) { 
        if (WiFi.status() != WL_CONNECTED) {
            wifiState = false;
            mqttState = false;
            
            Serial.printf("\n[NETWORK] Attempting WIFI -> SSID: '%s' | PASS: '%s'\n", wifi_ssid.c_str(), wifi_password.c_str());
            
            WiFi.begin(wifi_ssid.c_str(), wifi_password.c_str());
            
            int attempts = 0;
            while (WiFi.status() != WL_CONNECTED && attempts < 20) {
                vTaskDelay(500 / portTICK_PERIOD_MS);
                Serial.print(".");
                attempts++;
            }
            
            if (WiFi.status() == WL_CONNECTED) {
                Serial.printf("\n[NETWORK] WiFi Connected! IP: %s\n", WiFi.localIP().toString().c_str());
                wifiState = true; 
            } else {
                Serial.println("\n[NETWORK] WiFi Connection Failed. Retrying in 5s...");
                vTaskDelay(5000 / portTICK_PERIOD_MS); 
                continue; 
            }
        } else {
            wifiState = true;
        }

        if (WiFi.status() == WL_CONNECTED && !client.connected()) {
            mqttState = false; 
            Serial.printf("[NETWORK] Attempting MQTT connection to: %s:%d\n", mqtt_server_host.c_str(), mqtt_server_port);
            if (xSemaphoreTake(mqttMutex, portMAX_DELAY)) {
                // The PubSubClient connection routine can block up to 15 seconds waiting 
                // for the broker, which triggers the Core 0 Watchdog. We temporarily disable it.
                disableCore0WDT(); 
                bool isConnected = client.connect(DEVICE_ID);
                enableCore0WDT();
                
                if (isConnected) {
                    client.subscribe(topic_control);
                    Serial.println("[NETWORK] MQTT Connected!");
                    mqttState = true; 
                } else {
                    Serial.printf("[NETWORK] MQTT Failed, rc=%d. Retrying...\n", client.state());
                }
                xSemaphoreGive(mqttMutex); 
            }
            if (!client.connected()) {
                vTaskDelay(5000 / portTICK_PERIOD_MS); 
            }
        } else if (client.connected()) {
            mqttState = true;
        }

        if (client.connected()) {
            if (xSemaphoreTake(mqttMutex, (TickType_t)10)) {
                client.loop();
                xSemaphoreGive(mqttMutex);
            }
        }
        vTaskDelay(10 / portTICK_PERIOD_MS); 
    }
}

/*
 * CORE 1: MAIN SETUP
 */
void setup() {
    Serial.begin(115200);
    mqttMutex = xSemaphoreCreateMutex();

    preferences.begin("lettuvault", false);
    
    // --- FORCE UPDATE NVS CREDENTIALS ---
    // Uncomment these 3 lines if you want to force the ESP32 to ignore old saved passwords
    // preferences.putString("wifi_ssid", DEFAULT_WIFI_SSID);
    // preferences.putString("wifi_pass", DEFAULT_WIFI_PASSWORD);
    // preferences.putString("mqtt_serv", DEFAULT_MQTT_SERVER);
    
    // Load Network Settings (checking isKey first to avoid ESP32 core NOT_FOUND error logs)
    wifi_ssid = preferences.isKey("wifi_ssid") ? preferences.getString("wifi_ssid") : String(DEFAULT_WIFI_SSID);
    wifi_password = preferences.isKey("wifi_pass") ? preferences.getString("wifi_pass") : String(DEFAULT_WIFI_PASSWORD);
    mqtt_server_host = preferences.isKey("mqtt_serv") ? preferences.getString("mqtt_serv") : String(DEFAULT_MQTT_SERVER);
    mqtt_server_port = preferences.isKey("mqtt_port") ? preferences.getInt("mqtt_port") : DEFAULT_MQTT_PORT;
    // --- Setpoints are now Amnesiac ---
    // Will start with hardcoded default values and wait for Backend Sync to update.

    client.setServer(mqtt_server_host.c_str(), mqtt_server_port);
    client.setCallback(callback);
    client.setBufferSize(512);

    // --- I2C Initialization ---
    Wire.begin(); // Standard I2C: SDA=21, SCL=22
    delay(100);   // settle time for I2C pins
    
    // --- BME280 Initialization ---    
    Serial.println(F("[BME280] Probing standard I2C bus at address 0x76..."));
    if (bme.begin(0x76, &Wire)) {
        Serial.println(F("[BME280] ✅ Found at 0x76!"));
    } else {
        Serial.println(F("[BME280] Not found at 0x76. Trying 0x77..."));
        if (bme.begin(0x77, &Wire)) {
            Serial.println(F("[BME280] ✅ Found at 0x77!"));
        } else {
            Serial.println(F("[BME280] ❌ ERROR: Sensor not found! Check wiring (SDA=21, SCL=22) and I2C address."));
        }
    }

    if(display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { 
        display.setTextColor(SSD1306_WHITE);
        display.setTextSize(1);
        isDisplayFound = true;
    } else {
        Serial.println(F("[OLED] ❌ ERROR: OLED display not found at 0x3C. Screen will be disabled."));
        isDisplayFound = false;
    }

    // Initialize ALL Relays
    pinMode(RELAY_COMPRESSOR, OUTPUT);
    digitalWrite(RELAY_COMPRESSOR, LOW);  // OFF
    
    pinMode(RELAY_VACUUM, OUTPUT);
    digitalWrite(RELAY_VACUUM, HIGH);     // OFF
    
    pinMode(RELAY_HUMIDIFIER, OUTPUT);
    digitalWrite(RELAY_HUMIDIFIER, HIGH); // OFF

    xTaskCreatePinnedToCore(
        networkTask, "NetworkTask", 10000, NULL, 1, &NetworkTaskHandle, 0                   
    );

    // Bypass lockout on first boot so relays can act immediately if needed
    lastCompressorOffTime = millis() - RELAY_LOCKOUT_MS;
    lastVacuumOffTime     = millis() - RELAY_LOCKOUT_MS;
    lastHumidifierOffTime = millis() - RELAY_LOCKOUT_MS;
}

/*
 * CORE 1: MAIN SENSOR LOOP
 */
void loop() {
    unsigned long now = millis();
    
    if (wifiState != lastWifiState || mqttState != lastMqttState || forceDisplayUpdate) {
        updateDisplay();
        lastWifiState = wifiState;
        lastMqttState = mqttState;
        forceDisplayUpdate = false;
    }
    
    if (sendAckPending) {
        if (mqttState && xSemaphoreTake(mqttMutex, (TickType_t)10)) {
            String ackMsg = "{\"ack_id\":\"" + pendingAckId + "\"}";
            client.publish("lettuvault/ack", ackMsg.c_str());
            xSemaphoreGive(mqttMutex);
            sendAckPending = false;
        }
    }

    char key = keypad.getKey();
    if (key) {
        Serial.print("Key Pressed: ");
        Serial.println(key);
        forceDisplayUpdate = true;

        if (currentPage == PAGE_HOME) {
            if (key == '1') currentPage = PAGE_SYS_CONFIG;
            else if (key == '2') currentPage = PAGE_SYS_READ;
            else if (key == '3') currentPage = PAGE_NET_CONFIG;
        } 
        else if (currentPage == PAGE_SYS_CONFIG) {
            if (key == '*') currentPage = PAGE_EDIT_CONFIG;
            else if (key == 'D') currentPage = PAGE_HOME;
        }
        else if (currentPage == PAGE_EDIT_CONFIG) {
            if (key == '1') { currentPage = PAGE_NEW_VAL; subPageMode = 0; inputBuffer = ""; }
            else if (key == '2') { currentPage = PAGE_NEW_VAL; subPageMode = 1; inputBuffer = ""; }
            else if (key == '3') { currentPage = PAGE_NEW_VAL; subPageMode = 2; inputBuffer = ""; }
            else if (key == 'D') currentPage = PAGE_SYS_CONFIG;
        }
        else if (currentPage == PAGE_NEW_VAL) {
            if (key == 'A') {
                float val = inputBuffer.toFloat();
                bool changed = false;
                if (subPageMode == 0) { set_temperature = val; changed = true; }
                else if (subPageMode == 1) { set_humidity = val; changed = true; }
                else if (subPageMode == 2) { set_pressure = val; changed = true; }
                
                if (changed && wifiState && mqttState) {
                    JsonDocument syncDoc;
                    syncDoc["api_key"] = API_KEY;
                    syncDoc["device_id"] = DEVICE_ID;
                    syncDoc["temperature"] = set_temperature;
                    syncDoc["humidity"] = set_humidity;
                    syncDoc["pressure"] = set_pressure;
                    
                    char buffer[256];
                    serializeJson(syncDoc, buffer);
                    if (xSemaphoreTake(mqttMutex, (TickType_t)100)) {
                        client.publish(topic_config_sync, buffer);
                        xSemaphoreGive(mqttMutex);
                    }
                }
                
                currentPage = PAGE_SYS_CONFIG;
                inputBuffer = "";
            } else if (key == 'D') {
                currentPage = PAGE_EDIT_CONFIG;
                inputBuffer = "";
            } else if (key == 'B') {
                if (inputBuffer.length() > 0) {
                    inputBuffer.remove(inputBuffer.length() - 1);
                }
            } else if (key == '*') {
                inputBuffer += ".";
            } else if (key >= '0' && key <= '9') {
                inputBuffer += key;
            }
        }
        else if (currentPage == PAGE_SYS_READ) {
            if (key == 'D') currentPage = PAGE_HOME;
        }
        else if (currentPage == PAGE_NET_CONFIG) {
            if (key == '1') currentPage = PAGE_WIFI_STAT;
            else if (key == '2') { currentPage = PAGE_CHG_WIFI_SSID; inputBuffer = ""; }
            else if (key == '3') currentPage = PAGE_MQTT_STAT;
            else if (key == '4') { currentPage = PAGE_CHG_MQTT_SERV; inputBuffer = ""; }
            else if (key == 'D') currentPage = PAGE_HOME;
        }
        else if (currentPage == PAGE_WIFI_STAT) {
            if (key == 'D') currentPage = PAGE_NET_CONFIG;
        }
        else if (currentPage == PAGE_CHG_WIFI_SSID) {
            if (key == 'A') { 
                wifi_ssid = inputBuffer; 
                currentPage = PAGE_CHG_WIFI_PASS; 
                inputBuffer = ""; 
            }
            else if (key == 'D') currentPage = PAGE_NET_CONFIG;
            else if (key == 'B') {
                if (inputBuffer.length() > 0) inputBuffer.remove(inputBuffer.length() - 1);
            }
            else if (key != 'B' && key != 'C') inputBuffer += key; 
        }
        else if (currentPage == PAGE_CHG_WIFI_PASS) {
            if (key == 'A') { 
                wifi_password = inputBuffer; 
                preferences.putString("wifi_ssid", wifi_ssid);
                preferences.putString("wifi_pass", wifi_password);
                currentPage = PAGE_NET_CONFIG; 
                inputBuffer = "";
                WiFi.disconnect(); // Force reconnect with new settings
            }
            else if (key == 'D') currentPage = PAGE_NET_CONFIG;
            else if (key == 'B') {
                if (inputBuffer.length() > 0) inputBuffer.remove(inputBuffer.length() - 1);
            }
            else if (key != 'B' && key != 'C') inputBuffer += key;
        }
        else if (currentPage == PAGE_MQTT_STAT) {
            if (key == 'D') currentPage = PAGE_NET_CONFIG;
        }
        else if (currentPage == PAGE_CHG_MQTT_SERV) {
            if (key == 'A') { 
                mqtt_server_host = inputBuffer; 
                currentPage = PAGE_CHG_MQTT_PORT; 
                inputBuffer = ""; 
            }
            else if (key == 'D') currentPage = PAGE_NET_CONFIG;
            else if (key == 'B') {
                if (inputBuffer.length() > 0) inputBuffer.remove(inputBuffer.length() - 1);
            }
            else if (key == '*') inputBuffer += ".";
            else if (key != 'B' && key != 'C') inputBuffer += key;
        }
        else if (currentPage == PAGE_CHG_MQTT_PORT) {
            if (key == 'A') { 
                mqtt_server_port = inputBuffer.toInt(); 
                preferences.putString("mqtt_serv", mqtt_server_host);
                preferences.putInt("mqtt_port", mqtt_server_port);
                
                // Force disconnect from the old MQTT server
                client.disconnect(); 
                
                client.setServer(mqtt_server_host.c_str(), mqtt_server_port);
                currentPage = PAGE_NET_CONFIG; 
                inputBuffer = "";
            }
            else if (key == 'D') currentPage = PAGE_NET_CONFIG;
            else if (key == 'B') {
                if (inputBuffer.length() > 0) inputBuffer.remove(inputBuffer.length() - 1);
            }
            else if (key >= '0' && key <= '9') inputBuffer += key;
        }
    }

    // --- SENSOR & RELAY LOGIC (Runs periodically based on SENSOR_READ_INTERVAL_MS) ---
    if (now - lastMsg > SENSOR_READ_INTERVAL_MS) { 
        lastMsg = now;

        currentSensorTemp = bme.readTemperature();
        currentSensorHum = bme.readHumidity();
        currentSensorPres = bme.readPressure() / 100.0F;

        if (isnan(currentSensorTemp) || isnan(currentSensorHum) || isnan(currentSensorPres)) return; 

        // --- BME280 SENSOR LOG ---
        float dTemp = currentSensorTemp - set_temperature;
        float dHum  = currentSensorHum  - set_humidity;
        float dPres = currentSensorPres - set_pressure;
        Serial.println(F("================================================"));
        Serial.println(F("[BME280] Sensor Readings:"));
        Serial.print(F("  TEMP : ")); Serial.print(currentSensorTemp, 2); Serial.print(F(" C   (Set: ")); Serial.print(set_temperature, 2); 
        Serial.print(F(" | d: ")); Serial.print(dTemp >= 0 ? "+" : "-"); Serial.println(abs(dTemp), 2);
        
        Serial.print(F("  HUM  : ")); Serial.print(currentSensorHum, 2);  Serial.print(F(" %   (Set: ")); Serial.print(set_humidity, 2); 
        Serial.print(F(" | d: ")); Serial.print(dHum >= 0 ? "+" : "-");  Serial.println(abs(dHum), 2);
        
        Serial.print(F("  PRES : ")); Serial.print(currentSensorPres, 2); Serial.print(F(" hPa (Set: ")); Serial.print(set_pressure, 2); 
        Serial.print(F(" | d: ")); Serial.print(dPres >= 0 ? "+" : "-"); Serial.println(abs(dPres), 2);
        
        Serial.printf("[RELAYS]  Comp:%s  |  Vac:%s  |  Hum:%s\n", 
                      isCompressorRunning ? "ON" : "OFF", isVacuumRunning ? "ON" : "OFF", isHumidifierRunning ? "ON" : "OFF");
        Serial.println(F("================================================"));

        // Update display if we are on the reading page
        if (currentPage == PAGE_SYS_READ) forceDisplayUpdate = true;

        // --- 1. COMPRESSOR LOGIC (Board 1) ---
        if (currentSensorTemp > set_temperature + 1.5) {
            if (!isCompressorRunning && (now - lastCompressorOffTime >= RELAY_LOCKOUT_MS)) {
                digitalWrite(RELAY_COMPRESSOR, HIGH);
                isCompressorRunning = true;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Compressor ON  (Temp: %.2fC > Set: %.2fC)\n", currentSensorTemp, set_temperature);
            } else if (!isCompressorRunning) {
                unsigned long remaining = (RELAY_LOCKOUT_MS - (now - lastCompressorOffTime)) / 1000;
                Serial.printf("[RELAY] Compressor locked out. Ready in %lus\n", remaining);
            }
        } else if (currentSensorTemp <= set_temperature - 1.5) {
            if (isCompressorRunning) {
                digitalWrite(RELAY_COMPRESSOR, LOW);
                isCompressorRunning = false;
                lastCompressorOffTime = now;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Compressor OFF (Temp: %.2fC <= Set: %.2fC)\n", currentSensorTemp, set_temperature);
            }
        }

        // --- 2. VACUUM PUMP LOGIC (Board 2 - Active LOW: LOW=ON, HIGH=OFF) ---
        // ON when pressure is ABOVE setpoint, OFF when at or below
        if (currentSensorPres > set_pressure) {
            if (!isVacuumRunning && (now - lastVacuumOffTime >= RELAY_LOCKOUT_MS)) {
                digitalWrite(RELAY_VACUUM, LOW);   // Active LOW: LOW = ON
                isVacuumRunning = true;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Vacuum Pump ON  (Pres: %.2fhPa > Set: %.2fhPa)\n", currentSensorPres, set_pressure);
            } else if (!isVacuumRunning) {
                unsigned long remaining = (RELAY_LOCKOUT_MS - (now - lastVacuumOffTime)) / 1000;
                Serial.printf("[RELAY] Vacuum locked out. Ready in %lus\n", remaining);
            }
        } else {
            if (isVacuumRunning) {
                digitalWrite(RELAY_VACUUM, HIGH);  // Active LOW: HIGH = OFF
                isVacuumRunning = false;
                lastVacuumOffTime = now;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Vacuum Pump OFF (Pres: %.2fhPa <= Set: %.2fhPa)\n", currentSensorPres, set_pressure);
            }
        }

        // --- 3. HUMIDIFIER LOGIC (Board 2 - Active LOW: LOW=ON, HIGH=OFF) ---
        // ON when humidity is BELOW setpoint, OFF when at or above
        if (currentSensorHum < set_humidity) {
            if (!isHumidifierRunning && (now - lastHumidifierOffTime >= RELAY_LOCKOUT_MS)) {
                digitalWrite(RELAY_HUMIDIFIER, LOW);   // Active LOW: LOW = ON
                isHumidifierRunning = true;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Humidifier ON  (Hum: %.2f%% < Set: %.2f%%)\n", currentSensorHum, set_humidity);
            } else if (!isHumidifierRunning) {
                unsigned long remaining = (RELAY_LOCKOUT_MS - (now - lastHumidifierOffTime)) / 1000;
                Serial.printf("[RELAY] Humidifier locked out. Ready in %lus\n", remaining);
            }
        } else {
            if (isHumidifierRunning) {
                digitalWrite(RELAY_HUMIDIFIER, HIGH);  // Active LOW: HIGH = OFF
                isHumidifierRunning = false;
                lastHumidifierOffTime = now;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Humidifier OFF (Hum: %.2f%% >= Set: %.2f%%)\n", currentSensorHum, set_humidity);
            }
        }

        // --- PUBLISH TELEMETRY ---
        if (wifiState && mqttState) { 
            JsonDocument doc; 
            doc["api_key"] = API_KEY;
            doc["device_id"] = DEVICE_ID;
            doc["temperature"] = currentSensorTemp;
            doc["humidity"] = currentSensorHum;
            doc["pressure"] = currentSensorPres; 

            char buffer[256];
            serializeJson(doc, buffer);

            if (xSemaphoreTake(mqttMutex, (TickType_t)100)) {
                client.publish(topic_sensors, buffer);
                xSemaphoreGive(mqttMutex);
            }
        }
    }
}