#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h> // Switched to BME280
#include <ArduinoJson.h>

/* 
 * ---------------------------------------------------------------------------------------
 * CONFIGURATION - Change these values to match your network
 * ---------------------------------------------------------------------------------------
 */
const char* ssid = "YOUR_WIFI_SSID";         
const char* password = "YOUR_WIFI_PASSWORD"; 

// Use the local IP address of your COMPUTER running the backend
const char* mqtt_server = "192.168.x.x";     

const int mqtt_port = 1883;
const char* device_id = "ESP32-LettuVault-01";

// SECURITY: This must match the X_API_KEY in your .env file
const char* api_key = "lettuce-master-key-2024"; 

/* 
 * MQTT TOPICS
 */
const char* topic_sensors = "lettuvault/sensors";
const char* topic_control = "lettuvault/control"; 

/* 
 * HARDWARE SETUP
 */
Adafruit_BME280 bme; // Use BME280 instance
WiFiClient espClient;
PubSubClient client(espClient);
unsigned long lastMsg = 0;
unsigned long lastReconnectAttempt = 0;

void setup_wifi() {
    delay(10);
    Serial.println();
    Serial.print("Connecting to ");
    Serial.println(ssid);

    WiFi.begin(ssid, password);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi connected");
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println("\nWiFi connection failed!");
    }
}

void callback(char* topic, byte* payload, unsigned int length) {
    Serial.print("Message arrived [");
    Serial.print(topic);
    Serial.print("] ");
    
    String message;
    for (int i = 0; i < length; i++) {
        message += (char)payload[i];
    }
    Serial.println(message);

    if (message == "LED_ON") {
        Serial.println("Action: Turning LED ON");
    } else if (message == "LED_OFF") {
        Serial.println("Action: Turning LED OFF");
    }
}

boolean reconnect() {
    Serial.print("Attempting MQTT connection...");
    if (client.connect(device_id)) {
        Serial.println("connected");
        client.subscribe(topic_control);
    } else {
        Serial.print("failed, rc=");
        Serial.print(client.state());
        Serial.println(" try again in 5 seconds");
    }
    return client.connected();
}

void setup() {
    Serial.begin(115200);
    setup_wifi();
    client.setServer(mqtt_server, mqtt_port);
    client.setCallback(callback);

    // Initialize BME280
    unsigned status = bme.begin(0x76); // Standard I2C address for BME280
    if (!status) {
        Serial.println(F("Could not find a valid BME280 sensor, check wiring or try 0x77!"));
        status = bme.begin(0x77);
    }

    if (status) {
        Serial.println(F("BME280 initialized successfully"));
    }
}

void loop() {
    if (WiFi.status() != WL_CONNECTED) {
        WiFi.begin(ssid, password);
        delay(1000);
        return; 
    }

    if (!client.connected()) {
        unsigned long now = millis();
        if (now - lastReconnectAttempt > 5000) {
            lastReconnectAttempt = now;
            if (reconnect()) {
                lastReconnectAttempt = 0;
            }
        }
    } else {
        client.loop();
    }

    unsigned long now = millis();
    if (now - lastMsg > 3000) { 
        lastMsg = now;

        float temp = bme.readTemperature();
        float humidity = bme.readHumidity();
        float pressure = bme.readPressure() / 100.0F; // Convert Pa to hPa

        if (isnan(temp) || isnan(humidity) || isnan(pressure)) {
            Serial.println("Sensor Read Failed.");
        } else {
            if (client.connected()) {
                StaticJsonDocument<256> doc;
                doc["api_key"] = api_key;
                doc["device_id"] = device_id;
                doc["temperature"] = temp;
                doc["humidity"] = humidity;
                doc["pressure"] = pressure; 

                char buffer[256];
                serializeJson(doc, buffer);
                client.publish(topic_sensors, buffer);
                
                Serial.print("📤 [PUBLISHER] Published: ");
                Serial.println(buffer);
            }
        }
    }
}