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

// --- BME280 Setup (I2C Bus 1 - Wire1: SDA=32, SCL=33) ---
#define BME_SDA 32
#define BME_SCL 33
TwoWire I2C_BME = TwoWire(1);

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

// --- NON-VOLATILE STORAGE FOR DESIRED SETTINGS ---
Preferences preferences;
float set_temperature = 0.0;
float set_humidity = 0.0;
float set_pressure = 0.0;

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
bool isCompressorRunning = false;
bool isVacuumRunning = false;
bool isHumidifierRunning = false;
const unsigned long COMPRESSOR_LOCKOUT_MS = 180000; // 3 minutes

// --- RTOS & Object Setup ---
Adafruit_BME280 bme;
WiFiClient espClient;
PubSubClient client(espClient);

unsigned long lastMsg = 0;
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
    display.clearDisplay();
    display.setCursor(0, 0);
    display.setTextSize(1);

    switch (currentPage) {
        case PAGE_HOME:
            display.printf("WIFI:%s | MQTT:%s\n", wifiState ? "OK" : "NO", mqttState ? "OK" : "NO");
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
                lastCompressorOffTime = millis() - COMPRESSOR_LOCKOUT_MS; 
                Serial.printf("[HVAC] Target temp changed to %.1f. Lockout bypassed.\n", new_temp);
            }
            set_temperature = new_temp;
            preferences.putFloat("set_temp", set_temperature);
            changed = true;
        }
        if (!doc["humidity"].isNull()) {
            set_humidity = doc["humidity"].as<float>();
            preferences.putFloat("set_hum", set_humidity);
            changed = true;
        }
        if (!doc["pressure"].isNull()) {
            set_pressure = doc["pressure"].as<float>();
            preferences.putFloat("set_pres", set_pressure);
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
                if (client.connect(DEVICE_ID)) {
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
    
    // Load Network Settings
    wifi_ssid = preferences.getString("wifi_ssid", DEFAULT_WIFI_SSID);
    wifi_password = preferences.getString("wifi_pass", DEFAULT_WIFI_PASSWORD);
    mqtt_server_host = preferences.getString("mqtt_serv", DEFAULT_MQTT_SERVER);
    mqtt_server_port = preferences.getInt("mqtt_port", DEFAULT_MQTT_PORT);

    // Load Setpoints
    set_temperature = preferences.getFloat("set_temp", 25.0); 
    set_humidity = preferences.getFloat("set_hum", 60.0); 
    set_pressure = preferences.getFloat("set_pres", 1013.25);

    client.setServer(mqtt_server_host.c_str(), mqtt_server_port);
    client.setCallback(callback);
    client.setBufferSize(512);

    I2C_BME.begin(BME_SDA, BME_SCL);
    unsigned status = bme.begin(0x76, &I2C_BME);
    if (!status) status = bme.begin(0x77, &I2C_BME);

    if(display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { 
        display.setTextColor(SSD1306_WHITE);
        display.setTextSize(1);
    }

    // Initialize ALL Relays
    // Board 1 (Compressor): Active HIGH — HIGH=ON, LOW=OFF
    pinMode(RELAY_COMPRESSOR, OUTPUT);
    digitalWrite(RELAY_COMPRESSOR, LOW);  // OFF
    // Board 2 (Vacuum, Humidifier): Active LOW — LOW=ON, HIGH=OFF
    pinMode(RELAY_VACUUM, OUTPUT);
    digitalWrite(RELAY_VACUUM, HIGH);     // OFF
    pinMode(RELAY_HUMIDIFIER, OUTPUT);
    digitalWrite(RELAY_HUMIDIFIER, HIGH); // OFF

    preferences.begin("lettuvault", false);
    set_temperature = preferences.getFloat("set_temp", 25.0); 
    set_humidity = preferences.getFloat("set_hum", 60.0); 
    set_pressure = preferences.getFloat("set_pres", 1013.25); 

    xTaskCreatePinnedToCore(
        networkTask, "NetworkTask", 10000, NULL, 1, &NetworkTaskHandle, 0                   
    );

    // --- DESK TESTING FIX ADDED HERE ---
    // Trick the ESP32 into thinking the compressor has already been off for 3 minutes
    lastCompressorOffTime = 0 - COMPRESSOR_LOCKOUT_MS; 
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
                if (subPageMode == 0) { set_temperature = val; preferences.putFloat("set_temp", val); changed = true; }
                else if (subPageMode == 1) { set_humidity = val; preferences.putFloat("set_hum", val); changed = true; }
                else if (subPageMode == 2) { set_pressure = val; preferences.putFloat("set_pres", val); changed = true; }
                
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

    // --- SENSOR & RELAY LOGIC (Runs every 5 seconds) ---
    if (now - lastMsg > 5000) { 
        lastMsg = now;

        currentSensorTemp = bme.readTemperature();
        currentSensorHum = bme.readHumidity();
        currentSensorPres = bme.readPressure() / 100.0F;

        if (isnan(currentSensorTemp) || isnan(currentSensorHum) || isnan(currentSensorPres)) return; 

        Serial.printf("[CORE 1] Temp: %.2fC | Hum: %.2f%% | Pres: %.2fhPa\n", currentSensorTemp, currentSensorHum, currentSensorPres);

        // Update display if we are on the reading page
        if (currentPage == PAGE_SYS_READ) forceDisplayUpdate = true;

        // --- 1. COMPRESSOR LOGIC (Board 1) ---
        if (currentSensorTemp > set_temperature + 1.5) {
            if (!isCompressorRunning && (now - lastCompressorOffTime >= COMPRESSOR_LOCKOUT_MS)) {
                digitalWrite(RELAY_COMPRESSOR, HIGH);
                isCompressorRunning = true;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Compressor ON  (Temp: %.2fC > Set: %.2fC)\n", currentSensorTemp, set_temperature);
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
            if (!isVacuumRunning) {
                digitalWrite(RELAY_VACUUM, LOW);   // Active LOW: LOW = ON
                isVacuumRunning = true;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Vacuum Pump ON  (Pres: %.2fhPa > Set: %.2fhPa)\n", currentSensorPres, set_pressure);
            }
        } else {
            if (isVacuumRunning) {
                digitalWrite(RELAY_VACUUM, HIGH);  // Active LOW: HIGH = OFF
                isVacuumRunning = false;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Vacuum Pump OFF (Pres: %.2fhPa <= Set: %.2fhPa)\n", currentSensorPres, set_pressure);
            }
        }

        // --- 3. HUMIDIFIER LOGIC (Board 2 - Active LOW: LOW=ON, HIGH=OFF) ---
        // ON when humidity is BELOW setpoint, OFF when at or above
        if (currentSensorHum < set_humidity) {
            if (!isHumidifierRunning) {
                digitalWrite(RELAY_HUMIDIFIER, LOW);   // Active LOW: LOW = ON
                isHumidifierRunning = true;
                forceDisplayUpdate = true;
                Serial.printf("[RELAY] Humidifier ON  (Hum: %.2f%% < Set: %.2f%%)\n", currentSensorHum, set_humidity);
            }
        } else {
            if (isHumidifierRunning) {
                digitalWrite(RELAY_HUMIDIFIER, HIGH);  // Active LOW: HIGH = OFF
                isHumidifierRunning = false;
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