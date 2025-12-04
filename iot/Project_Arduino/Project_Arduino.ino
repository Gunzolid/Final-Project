#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "ArduinoJson.h"


// 1. ส่วนตั้งค่าการเชื่อมต่อ (CONFIGURATION)
// ตั้งค่า Wi-Fi *Importance*
const char* WIFI_SSID = "Your Wifi SSID";
const char* WIFI_PASSWORD = "Your Wifi Password";

// ตั้งค่า Firebase Project
#define FIREBASE_API_KEY "Your Firebase API Key"
#define FIREBASE_PROJECT_ID "Your Firebase Project ID"

// ตั้งค่าบัญชีผู้ใช้ (Authentication)
#define USER_EMAIL "Your Firebase User Email for IOT"
#define USER_PASSWORD "Your Firebase User Password for IOT"


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

// ตัวแปรเก็บสถานะ
String localSensorStatus = "available"; 
String lastSentStatus = "available";    
bool isUnavailable = false; 
bool lastWifiState = false; // ไว้เช็คว่าเน็ตเพิ่งต่อติดหรือเพิ่งหลุด

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

// 4. SETUP
void setup() {
  Serial.begin(115200);
  Serial.println("\n\n--- Starting Smart Parking System ---");

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // เริ่มต้น WiFi แบบไม่รอ (Non-blocking)
  Serial.println("[WiFi] Connecting to " + String(WIFI_SSID) + "...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // ตั้งค่า Firebase
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.timeout.serverResponse = 5000; 
  config.timeout.wifiReconnect = 1000;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("[System] Setup Complete. Running in Offline Mode until connected.");
}


// 5. LOOP
void loop() {
  unsigned long currentMillis = millis();

  // เช็คสถานะ Wi-Fi และแจ้งเตือนทาง Serial
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

  // อ่านเซ็นเซอร์และคุมไฟ (ทำงานตลอดเวลา) 
  if (currentMillis - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = currentMillis;

    // ถ้า Admin สั่งปิด (Unavailable) ให้ดับไฟและข้ามการอ่านค่าไปเลย
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

      if (localSensorStatus == "occupied") {
        digitalWrite(LED_PIN, HIGH);
      } else {
        digitalWrite(LED_PIN, LOW);
      }
    }
  }

  // จัดการ Firebase (ทำเมื่อมีเน็ต)
  if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
    
    // เช็คสถานะจาก Server (Admin สั่งปิดไหม?)
    if (currentMillis - lastFirebaseCheck >= FIREBASE_CHECK_INTERVAL) {
      lastFirebaseCheck = currentMillis;
      String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
      
      if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str())) {
        StaticJsonDocument<256> doc;
        deserializeJson(doc, fbdo.payload());
        if (doc["fields"]["status"]["stringValue"]) {
          String remoteVal = String(doc["fields"]["status"]["stringValue"]);
          
          // อัปเดตสถานะ isUnavailable ตามค่าจาก Server
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