#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "ArduinoJson.h"
#include <Preferences.h>


// 1. ส่วนตั้งค่า (CONFIGURATION)
// ค่า Default (กรณีเริ่มใช้ครั้งแรก หรือยังไม่ได้ตั้งค่าผ่าน Serial)
String wifi_ssid = "Gunza2022_2.4G";
String wifi_pass = "0937426904";

#define FIREBASE_API_KEY "AIzaSyA9tqJbkkl3iA-c4-m0Uj1VvNc4dsrX1ds"
#define FIREBASE_PROJECT_ID "project-4f636"
#define USER_EMAIL "esp32-device-01@yourproject.com"
#define USER_PASSWORD "a_very_strong_password_1234"

// ส่วน Hardware
#define PARKING_SPOT_ID "1"
const int CAR_DETECT_THRESHOLD_CM = 75;
const int TRIG_PIN = 5;
const int ECHO_PIN = 18;
const int LED_PIN = 2;


// 2. ตัวแปรระบบ
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
Preferences preferences; // ตัวแปรจัดการหน่วยความจำ

// ตัวแปรเก็บสถานะ
String localSensorStatus = "available"; 
String lastSentStatus = "available";    
bool isUnavailable = false; 
bool lastWifiState = false; 

// ตัวแปรเวลา
unsigned long lastSensorRead = 0;
unsigned long lastFirebaseCheck = 0;
const long SENSOR_INTERVAL = 500;       
const long FIREBASE_CHECK_INTERVAL = 10000; 

 
// 3. ฟังก์ชันอ่านระยะทาง
float readDistanceCM(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  unsigned long us = pulseIn(echoPin, HIGH, 30000UL);
  if (us == 0) return NAN;
  return us * 0.01715;
}


// 4. ฟังก์ชันจัดการคำสั่ง Serial (NEW!)
void checkSerialCommand() {
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim(); // ตัดช่องว่างหัวท้ายออก

    if (input.startsWith("ssid:")) {
      String newSSID = input.substring(5);
      if (newSSID.length() > 0) {
        preferences.begin("wifi-config", false); // เปิดโหมดเขียน
        preferences.putString("ssid", newSSID);
        preferences.end();
        Serial.println("\n[Config] SSID updated to: " + newSSID);
        Serial.println("[Config] Restarting to apply changes...");
        delay(1000);
        ESP.restart();
      }
    } 
    else if (input.startsWith("pass:")) {
      String newPass = input.substring(5);
      if (newPass.length() > 0) {
        preferences.begin("wifi-config", false); // เปิดโหมดเขียน
        preferences.putString("pass", newPass);
        preferences.end();
        Serial.println("\n[Config] Password updated.");
        Serial.println("[Config] Restarting to apply changes...");
        delay(1000);
        ESP.restart();
      }
    }
    else {
      Serial.println("\n[Error] Unknown command.");
      Serial.println("Use 'ssid:YOUR_SSID' or 'pass:YOUR_PASSWORD'");
    }
  }
}

// 5. SETUP
void setup() {
  Serial.begin(115200);
  Serial.println("\n\n--- Starting Smart Parking System ---");

  // โหลดค่า Wi-Fi จาก Memory (ถ้ามี)
  preferences.begin("wifi-config", true); // โหมดอ่านอย่างเดียว
  String storedSSID = preferences.getString("ssid", "");
  String storedPass = preferences.getString("pass", "");
  preferences.end();

  if (storedSSID != "") {
    wifi_ssid = storedSSID;
    wifi_pass = storedPass;
    Serial.println("[Config] Loaded Wi-Fi from memory: " + wifi_ssid);
  } else {
    Serial.println("[Config] Using default Wi-Fi: " + wifi_ssid);
  }

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // เริ่มต้น WiFi แบบไม่รอ (Non-blocking)
  Serial.println("[WiFi] Connecting to " + wifi_ssid + "...");
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
  
  // ตั้งค่า Firebase
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.timeout.serverResponse = 5000; 
  config.timeout.wifiReconnect = 1000;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("[System] Setup Complete. Type 'ssid:NAME' or 'pass:KEY' to change Wi-Fi.");
}


// 6. LOOP
void loop() {
  unsigned long currentMillis = millis();

  // ตรวจจับคำสั่งเปลี่ยน Wi-Fi ---
  checkSerialCommand();

  // เช็คสถานะ Wi-Fi และแจ้งเตือนทาง Serial ---
  bool currentWifiState = (WiFi.status() == WL_CONNECTED);
  if (currentWifiState != lastWifiState) {
    if (currentWifiState) {
      Serial.println("\n[WiFi] >>> CONNECTED! IP: " + WiFi.localIP().toString());
      Serial.println("[Firebase] Initializing connection...");
    } else {
      Serial.println("\n[WiFi] >>> DISCONNECTED! Connection lost.");
    }
    lastWifiState = currentWifiState;
  }

  // อ่านเซ็นเซอร์และคุมไฟ (ทำงานตลอดเวลา) ---
  if (currentMillis - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = currentMillis;

    if (isUnavailable) {
       digitalWrite(LED_PIN, LOW);
       return; 
    }

    float distance = readDistanceCM(TRIG_PIN, ECHO_PIN);
    
    if (!isnan(distance)) {
      String newStatus = (distance < CAR_DETECT_THRESHOLD_CM) ? "occupied" : "available";

      if (newStatus != localSensorStatus) {
         Serial.println("\n--------------------------------");
         Serial.printf("[Sensor] Distance: %.1f cm\n", distance);
         if(newStatus == "occupied") {
            Serial.println("[Status] Car Detected! (Occupied) -> LED ON");
         } else {
            Serial.println("[Status] Spot Freed! (Available) -> LED OFF");
         }
         Serial.println("--------------------------------");
      }

      localSensorStatus = newStatus;

      if (distance < CAR_DETECT_THRESHOLD_CM) {
        digitalWrite(LED_PIN, HIGH);
      } else {
        digitalWrite(LED_PIN, LOW);
      }
    }
  }

  // จัดการ Firebase (ทำเมื่อมีเน็ต) ---
  if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
    
    // 2.1 เช็คสถานะจาก Server (Admin สั่งปิดไหม?)
    if (currentMillis - lastFirebaseCheck >= FIREBASE_CHECK_INTERVAL) {
      lastFirebaseCheck = currentMillis;
      String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
      
      if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str())) {
        StaticJsonDocument<256> doc;
        deserializeJson(doc, fbdo.payload());
        if (doc["fields"]["status"]["stringValue"]) {
          String remoteVal = String(doc["fields"]["status"]["stringValue"]);
          
          if (remoteVal == "unavailable") {
            if (!isUnavailable) Serial.println("\n[Admin] Spot set to UNAVAILABLE by server.");
            isUnavailable = true;
          } else {
            if (isUnavailable) Serial.println("\n[Admin] Spot is now ACTIVE.");
            isUnavailable = false;
          }
        }
      }
    }

    // ส่งข้อมูลขึ้น Cloud (เมื่อค่าไม่ตรง และต้องไม่ Unavailable)
    if (localSensorStatus != lastSentStatus && !isUnavailable) {
      Serial.print("[Sync] Updating Firebase (" + localSensorStatus + ")... ");
      
      String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
      String content = "{\"fields\": {\"status\": {\"stringValue\": \"" + localSensorStatus + "\"}}}";
      
      if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.c_str(), "status")) {
         Serial.println("SUCCESS!");
         lastSentStatus = localSensorStatus; 
      } else {
         Serial.print("FAILED! Reason: ");
         Serial.println(fbdo.errorReason());
      }
    }
  }
}