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
// RESERVED FOR FUTURE RELAYS: 25, 26, 27, 32

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
bool forceDisplayUpdate = true; // Forces an update on boot

// --- ACK DEFERRAL (For cross-core safety) ---
volatile bool sendAckPending = false;
String pendingAckId = "";

/*
 * HELPER FUNCTION: UPDATE OLED DISPLAY
 * Note: Only Core 1 should call this to avoid I2C bus crashes!
 */
void updateDisplay() {
    display.clearDisplay();
    display.setCursor(0, 0);     
    
    display.println(F("System Online"));
    display.println(); // Blank line for spacing

    if (wifiState) {
        display.println(F("WIFI connected"));
    } else {
        display.println(F("WIFI disconnected"));
    }
    
    if (mqttState) {
        display.println(F("MQTT connected"));
    } else {
        display.println(F("MQTT disconnected"));
    }
    
    display.println(); // Blank line for spacing
    display.println(F("System Config"));
    display.printf("Temp:%.1f Humid:%.1f\n", set_temperature, set_humidity);
    display.printf("Pressure:%.1f\n", set_pressure);
    
    display.display(); // Push to screen
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

    // Try parsing as JSON for System Configuration
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, message);

    if (!error) {
        bool changed = false;
        
        // PUBLISH ACKNOWLEDGE BACK TO BACKEND
        if (doc.containsKey("tx_id")) {
            pendingAckId = doc["tx_id"].as<String>();
            sendAckPending = true; // Queue the ACK for Core 1
            Serial.printf("Will send ACK for %s on next loop cycle\n", pendingAckId.c_str());
        }

        if (doc.containsKey("temperature")) {
            set_temperature = doc["temperature"];
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
            Serial.printf("Updated Settings: Temp=%.2fC, Hum=%.2f%%, Pres=%.2fhPa\n", set_temperature, set_humidity, set_pressure);
            forceDisplayUpdate = true;
        }
    } else {
        // Fallback for non-JSON string commands
        if (message == "LED_ON") {
            Serial.println("Action: Turning LED ON");
        } else if (message == "LED_OFF") {
            Serial.println("Action: Turning LED OFF");
        }
    }
}

/*
 * CORE 0: NETWORK TASK 
 */
void networkTask(void * parameter) {
    for(;;) { 
        // 1. Check Wi-Fi
        if (WiFi.status() != WL_CONNECTED) {
            wifiState = false;
            mqttState = false;
            
            Serial.println("[CORE 0] Connecting to WiFi...");
            WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
            
            int attempts = 0;
            while (WiFi.status() != WL_CONNECTED && attempts < 20) {
                vTaskDelay(500 / portTICK_PERIOD_MS);
                Serial.print(".");
                attempts++;
            }
            
            if (WiFi.status() == WL_CONNECTED) {
                Serial.println("\n[CORE 0] WiFi connected!");
                wifiState = true; 
            } else {
                Serial.println("\n[CORE 0] WiFi failed. Retrying later.");
                vTaskDelay(5000 / portTICK_PERIOD_MS); 
                continue; 
            }
        } else {
            wifiState = true;
        }

        // 2. Check MQTT
        if (WiFi.status() == WL_CONNECTED && !client.connected()) {
            mqttState = false; 
            Serial.println("[CORE 0] Connecting to MQTT...");
            
            if (xSemaphoreTake(mqttMutex, portMAX_DELAY)) {
                if (client.connect(DEVICE_ID)) {
                    Serial.println("[CORE 0] MQTT connected!");
                    client.subscribe(topic_control);
                    mqttState = true; 
                } else {
                    Serial.printf("[CORE 0] MQTT failed, rc=%d\n", client.state());
                }
                xSemaphoreGive(mqttMutex); 
            }
            
            if (!client.connected()) {
                vTaskDelay(5000 / portTICK_PERIOD_MS); 
            }
        } else if (client.connected()) {
            mqttState = true;
        }

        // 3. Maintain MQTT Connection
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

    // Initialize BME280
    unsigned status = bme.begin(0x76);
    if (!status) {
        Serial.println(F("Could not find a valid BME280 sensor, check wiring!"));
        status = bme.begin(0x77);
    }
    if (status) Serial.println(F("BME280 initialized successfully"));

    // Initialize OLED Display
    if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { 
        Serial.println(F("SSD1306 allocation failed"));
    } else {
        Serial.println(F("OLED initialized successfully"));
        display.setTextColor(SSD1306_WHITE);
        display.setTextSize(1);
        updateDisplay(); // Show initial disconnected state
    }

    // Initialize Preferences and load set values
    preferences.begin("lettuvault", false);
    set_temperature = preferences.getFloat("set_temp", 25.0); // default 25.0
    set_humidity = preferences.getFloat("set_hum", 60.0); // default 60.0
    set_pressure = preferences.getFloat("set_pres", 1013.25); // default 1013.25
    Serial.printf("[CORE 1] Loaded Settings: Temp=%.2fC, Hum=%.2f%%, Pres=%.2fhPa\n", set_temperature, set_humidity, set_pressure);

    // Pin the Network Task to Core 0
    xTaskCreatePinnedToCore(
        networkTask,        
        "NetworkTask",      
        10000,              
        NULL,               
        1,                  
        &NetworkTaskHandle, 
        0                   
    );

    Serial.println("[CORE 1] Main setup complete. Starting sensor loop...");
}

/*
 * CORE 1: MAIN SENSOR LOOP
 */
void loop() {
    unsigned long now = millis();
    
    // --- DISPLAY UPDATE LOGIC ---
    // Safely check if Core 0 changed the connection states. If so, update OLED.
    if (wifiState != lastWifiState || mqttState != lastMqttState || forceDisplayUpdate) {
        updateDisplay();
        lastWifiState = wifiState;
        lastMqttState = mqttState;
        forceDisplayUpdate = false;
    }
    
    // --- SEND ACK LOGIC (Safely on Core 1) ---
    if (sendAckPending) {
        if (mqttState && xSemaphoreTake(mqttMutex, (TickType_t)10)) {
            String ackMsg = "{\"ack_id\":\"" + pendingAckId + "\"}";
            client.publish("lettuvault/ack", ackMsg.c_str());
            Serial.printf("Sent ACK for %s\n", pendingAckId.c_str());
            xSemaphoreGive(mqttMutex);
            sendAckPending = false;
        }
    }

    // --- KEYPAD LOGIC (Waiting for future instructions) ---
    char key = keypad.getKey();
    if (key) {
        Serial.print("Key Pressed: ");
        Serial.println(key);
    }

    // --- SENSOR LOGIC (Runs every 5 seconds) ---
    if (now - lastMsg > 5000) { 
        lastMsg = now;

        float temp = bme.readTemperature();
        float humidity = bme.readHumidity();
        float pressure = bme.readPressure() / 100.0F;

        if (isnan(temp) || isnan(humidity) || isnan(pressure)) {
            Serial.println("[CORE 1] Sensor Read Failed.");
            return; 
        }

        Serial.printf("[CORE 1] Temp: %.2fC | Hum: %.2f%% | Pres: %.2fhPa\n", temp, humidity, pressure);

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
                Serial.print("📤 [PUBLISHER] Sent: ");
                Serial.println(buffer);
            } else {
                Serial.println("⚠️ [PUBLISHER] Failed to get Mutex, skipped sending.");
            }
        } else {
            Serial.println("⏳ [PUBLISHER] Network offline. Data read, but skipped sending.");
        }
    }
}