#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "ArduinoJson.h"
#include <Preferences.h>


// 1. ส่วนตั้งค่า (CONFIGURATION)
// ค่า Default (กรณีเริ่มใช้ครั้งแรก หรือยังไม่ได้ตั้งค่าผ่าน Serial)
String wifi_ssid = "WiFi Name";
String wifi_pass = "WiFi Password";

#define FIREBASE_API_KEY "Firebase API Key"
#define FIREBASE_PROJECT_ID "Firebase Project ID"
#define USER_EMAIL "Firebase IOT User Email"
#define USER_PASSWORD "Firebase IOT User Password"

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


// 4. ฟังก์ชันจัดการคำสั่ง Serial
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

  // โหลดค่า Wi-Fi จาก Memory
  preferences.begin("wifi-config", true);
  String storedSSID = preferences.getString("ssid", "");
  String storedPass = preferences.getString("pass", "");
  preferences.end();

  if (storedSSID != "") {
    wifi_ssid = storedSSID;
    wifi_pass = storedPass;
    Serial.println("[Config] Loaded Wi-Fi: " + wifi_ssid);
  } else {
    Serial.println("[Config] Using default Wi-Fi: " + wifi_ssid);
  }

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // เริ่มส่วนการเชื่อมต่อแบบมี Timeout 10 วินาที
  Serial.println("[WiFi] Connecting to " + wifi_ssid + "...");
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());

  unsigned long startAttemptTime = millis();
  bool isConnectedInSetup = false;

  // วนลูปรอการเชื่อมต่อไม่เกิน 10 วินาที (10000 ms)
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 10000) {
    delay(500);
    Serial.print(".");
  }

  // ตรวจสอบผลลัพธ์หลังผ่านไป 10 วินาที หรือต่อติดแล้ว
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] Connected successfully!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    isConnectedInSetup = true;
  } else {
    Serial.println("\n[WiFi] Timeout! Internet not found.");
    Serial.println("[System] Activating OFFLINE MODE.");
    Serial.println("[System] Sensor will work, but data won't sync until WiFi returns.");
  }

  // ตั้งค่า Firebase ไว้เสมอ (แม้ Offline ก็ตั้งค่าได้ Library จะจัดการรอเอง)
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.timeout.serverResponse = 5000; 
  config.timeout.wifiReconnect = 1000;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true); // คำสั่งนี้สำคัญ ช่วยให้มันต่อเองตอนเน็ตมา
  
  Serial.println("[System] Setup Complete.");
}

// 6. LOOP
void loop() {
  unsigned long currentMillis = millis();

  // ตรวจจับคำสั่งเปลี่ยน Wi-Fi
  checkSerialCommand();

  // เช็คสถานะ Wi-Fi และแจ้งเตือน (ส่วนนี้จะทำงานเมื่อเน็ตหลุด/หรือกลับมา)
  bool currentWifiState = (WiFi.status() == WL_CONNECTED);
  if (currentWifiState != lastWifiState) {
    if (currentWifiState) {
      Serial.println("\n[WiFi] >>> RECONNECTED! Switching to ONLINE MODE.");
      Serial.println("[Firebase] Resuming synchronization...");
    } else {
      Serial.println("\n[WiFi] >>> DISCONNECTED! Switching to OFFLINE MODE.");
    }
    lastWifiState = currentWifiState;
  }

  // อ่านเซ็นเซอร์และคุมไฟ (ทำงานตลอดเวลา ไม่สนเน็ต)
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
            Serial.println("[Status] Car Detected! -> LED ON");
         } else {
            Serial.println("[Status] Spot Freed! -> LED OFF");
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

  // จัดการ Firebase (ทำเมื่อมีเน็ตเท่านั้น) 
  if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
    
    // 2.1 เช็คสถานะจาก Server (Admin สั่งปิดไหม?)
    if (currentMillis - lastFirebaseCheck >= FIREBASE_CHECK_INTERVAL) {
      lastFirebaseCheck = currentMillis;
      String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
      
      if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str())) {
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, fbdo.payload());
        
        if (!error && doc["fields"]["status"]["stringValue"]) {
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