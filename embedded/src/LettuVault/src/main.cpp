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
#define WIFI_SSID       "Mappie"
#define WIFI_PASSWORD   "Aa1231325213!"
#define MQTT_SERVER     "192.168.137.1"
#define MQTT_PORT       1883
#define DEVICE_ID       "ESP32-LettuVault-01"
#define API_KEY         "lettuce-master-key-2024" 

const char* topic_sensors = "lettuvault/sensors";
const char* topic_control = "lettuvault/control"; 

/* * HARDWARE PINS & SETUP
 * ---------------------------------------------------------------------------------------
 */
// --- RELAY PINS (Single ESP32 -> Two 4-Channel Relay Boards) ---
#define RELAY_COMPRESSOR 25 // Board 1 - IN1 (30A)
#define RELAY_VACUUM     26 // Board 2 - IN1 (10A)
#define RELAY_HUMIDIFIER 27 // Board 2 - IN2 (10A)

// --- OLED Display Setup ---
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1 
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

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
byte colPins[COLS] = {13, 14, 23, 33}; 

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// --- NON-VOLATILE STORAGE FOR DESIRED SETTINGS ---
Preferences preferences;
float set_temperature = 0.0;
float set_humidity = 0.0;
float set_pressure = 0.0;

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
    
    // Line 1: Network Status
    display.print(F("WIFI:"));
    display.print(wifiState ? "OK  " : "NO  ");
    display.print(F("MQTT:"));
    display.println(mqttState ? "OK" : "NO");
    
    // Line 2, 3, 4: Setpoints
    display.println(F("--- SETPOINTS ---"));
    display.printf("T:%.1fC H:%.1f%%\n", set_temperature, set_humidity);
    display.printf("P:%.1fhPa\n", set_pressure);
    
    // Line 5, 6, 7: Hardware Status (All on one screen)
    display.println(F("--- HARDWARE ---"));
    display.print(F("Comp: "));
    display.println(isCompressorRunning ? F("ON") : F("OFF"));
    display.printf("Vac:%s Hum:%s\n", isVacuumRunning ? "ON" : "OFF", isHumidifierRunning ? "ON" : "OFF");
    
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
        
        if (doc.containsKey("tx_id")) {
            pendingAckId = doc["tx_id"].as<String>();
            sendAckPending = true; 
        }

        if (doc.containsKey("temperature")) {
            float new_temp = doc["temperature"];
            if (set_temperature != new_temp) {
                lastCompressorOffTime = millis() - COMPRESSOR_LOCKOUT_MS; 
                Serial.printf("⚠️ [HVAC] Target temp changed to %.1f. Lockout bypassed.\n", new_temp);
            }
            set_temperature = new_temp;
            preferences.putFloat("set_temp", set_temperature);
            changed = true;
        }
        if (doc.containsKey("humidity")) {
            set_humidity = doc["humidity"];
            preferences.putFloat("set_hum", set_humidity);
            changed = true;
        }
        if (doc.containsKey("pressure")) {
            set_pressure = doc["pressure"];
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
            WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
            
            int attempts = 0;
            while (WiFi.status() != WL_CONNECTED && attempts < 20) {
                vTaskDelay(500 / portTICK_PERIOD_MS);
                attempts++;
            }
            
            if (WiFi.status() == WL_CONNECTED) {
                wifiState = true; 
            } else {
                vTaskDelay(5000 / portTICK_PERIOD_MS); 
                continue; 
            }
        } else {
            wifiState = true;
        }

        if (WiFi.status() == WL_CONNECTED && !client.connected()) {
            mqttState = false; 
            if (xSemaphoreTake(mqttMutex, portMAX_DELAY)) {
                if (client.connect(DEVICE_ID)) {
                    client.subscribe(topic_control);
                    mqttState = true; 
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

    client.setServer(MQTT_SERVER, MQTT_PORT);
    client.setCallback(callback);
    client.setBufferSize(512);

    unsigned status = bme.begin(0x76);
    if (!status) status = bme.begin(0x77);

    if(display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { 
        display.setTextColor(SSD1306_WHITE);
        display.setTextSize(1);
        updateDisplay(); 
    }

    // Initialize ALL Relays across both boards
    pinMode(RELAY_COMPRESSOR, OUTPUT);
    digitalWrite(RELAY_COMPRESSOR, LOW);
    pinMode(RELAY_VACUUM, OUTPUT);
    digitalWrite(RELAY_VACUUM, LOW);
    pinMode(RELAY_HUMIDIFIER, OUTPUT);
    digitalWrite(RELAY_HUMIDIFIER, LOW);

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
    }

    // --- SENSOR & RELAY LOGIC (Runs every 5 seconds) ---
    if (now - lastMsg > 5000) { 
        lastMsg = now;

        float temp = bme.readTemperature();
        float humidity = bme.readHumidity();
        float pressure = bme.readPressure() / 100.0F;

        if (isnan(temp) || isnan(humidity) || isnan(pressure)) return; 

        Serial.printf("[CORE 1] Temp: %.2fC | Hum: %.2f%% | Pres: %.2fhPa\n", temp, humidity, pressure);

        // --- 1. COMPRESSOR LOGIC (Board 1) ---
        if (temp > set_temperature + 1.5) {
            if (!isCompressorRunning && (now - lastCompressorOffTime >= COMPRESSOR_LOCKOUT_MS)) {
                digitalWrite(RELAY_COMPRESSOR, HIGH);
                isCompressorRunning = true;
                forceDisplayUpdate = true; 
            }
        } else if (temp <= set_temperature - 1.5) {
            if (isCompressorRunning) {
                digitalWrite(RELAY_COMPRESSOR, LOW);
                isCompressorRunning = false;
                lastCompressorOffTime = now; 
                forceDisplayUpdate = true; 
            }
        }

        // --- 2. VACUUM PUMP LOGIC (Board 2) ---
        float pres_tol = set_pressure * 0.05;
        if (pressure > set_pressure + pres_tol) {
            if (!isVacuumRunning) {
                digitalWrite(RELAY_VACUUM, HIGH);
                isVacuumRunning = true;
                forceDisplayUpdate = true; 
            }
        } else if (pressure <= set_pressure - pres_tol) {
            if (isVacuumRunning) {
                digitalWrite(RELAY_VACUUM, LOW);
                isVacuumRunning = false;
                forceDisplayUpdate = true; 
            }
        }

        // --- 3. HUMIDIFIER LOGIC (Board 2) ---
        if (humidity < set_humidity - 5.0) {
            if (!isHumidifierRunning) {
                digitalWrite(RELAY_HUMIDIFIER, HIGH);
                isHumidifierRunning = true;
                forceDisplayUpdate = true; 
            }
        } else if (humidity >= set_humidity + 5.0) {
            if (isHumidifierRunning) {
                digitalWrite(RELAY_HUMIDIFIER, LOW);
                isHumidifierRunning = false;
                forceDisplayUpdate = true; 
            }
        }

        // --- PUBLISH TELEMETRY ---
        if (wifiState && mqttState) { 
            JsonDocument doc; 
            doc["api_key"] = API_KEY;
            doc["device_id"] = DEVICE_ID;
            doc["temperature"] = temp;
            doc["humidity"] = humidity;
            doc["pressure"] = pressure; 

            char buffer[256];
            serializeJson(doc, buffer);

            if (xSemaphoreTake(mqttMutex, (TickType_t)100)) {
                client.publish(topic_sensors, buffer);
                xSemaphoreGive(mqttMutex);
            }
        }
    }
}