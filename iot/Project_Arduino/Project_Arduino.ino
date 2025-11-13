#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "ArduinoJson.h"
#include "time.h"

// ============== CONFIGURATION =====================================
// --- 1. ตั้งค่า Wi-Fi ---
const char* WIFI_SSID = "Gunza2022_2.4G";
const char* WIFI_PASSWORD = "0937426904";

// --- 2. ตั้งค่า Firebase Project ---
#define FIREBASE_API_KEY "AIzaSyA9tqJbkkl3iA-c4-m0Uj1VvNc4dsrX1ds"
#define FIREBASE_PROJECT_ID "project-4f636"
#define FIREBASE_DATABASE_URL "project-4f636-default-rtdb.firebaseio.com"

// --- 3. ตั้งค่าบัญชีผู้ใช้สำหรับอุปกรณ์ ---
#define USER_EMAIL "esp32-device-01@yourproject.com"
#define USER_PASSWORD "a_very_strong_password_1234"

// --- 4. ตั้งค่าเซ็นเซอร์ (1 ตัว) ---
#define PARKING_SPOT_ID "1"
const int CAR_DETECT_THRESHOLD_CM = 100;
const int TRIG_PIN = 5;
const int ECHO_PIN = 18;

// --- 5. ตั้งค่า NTP Server ---
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7 * 3600;
const int daylightOffset_sec = 0;
// =================================================================

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

String lastSentStatus = "";
bool firebaseReady = false;

void setup() {
  Serial.begin(115200);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  digitalWrite(TRIG_PIN, LOW);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());

  Serial.print("Syncing time with NTP server");
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  struct tm timeinfo;
  while (!getLocalTime(&timeinfo)) {
    Serial.print(".");
    delay(1000);
  }
  Serial.println("\nTime synced successfully!");

  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

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

void loop() {
  if (Firebase.ready()) {
    if (!firebaseReady) {
      Serial.println(">>> Firebase connection is ready. Starting sensor readings...");
      firebaseReady = true;
    }

    Serial.println("------------------------------");
    Serial.printf("Checking spot %s...\n", PARKING_SPOT_ID);

    String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);

    // 1. อ่านสถานะล่าสุดจาก Firebase ก่อนเสมอ
    Serial.println(" > Getting current status from Firebase...");
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str())) {

      // ใช้ ArduinoJson เพื่อดึงค่า status ออกมา
      StaticJsonDocument<256> doc;
      deserializeJson(doc, fbdo.payload());
      const char* remoteStatusStr = doc["fields"]["status"]["stringValue"];

      if (remoteStatusStr) {
        String currentRemoteStatus = String(remoteStatusStr);
        Serial.printf(" > Remote status is: '%s'\n", currentRemoteStatus.c_str());
        lastSentStatus = currentRemoteStatus;  // อัปเดตสถานะล่าสุดในเครื่องให้ตรงกับเซิร์ฟเวอร์

        // 2. ตรวจสอบเงื่อนไข ถ้าเป็น 'unavailable' ให้ข้ามไปเลย
        if (currentRemoteStatus == "unavailable") {
          Serial.println(" > Spot is 'unavailable'. Skipping sensor check.");
        } else {
          // 3. ถ้าไม่ใช่ 'unavailable' ให้ทำงานตามปกติ
          float distance = readDistanceCM(TRIG_PIN, ECHO_PIN);
          String sensorStatus = "";

          if (isnan(distance)) {
            Serial.println(" > Reading failed: Timeout / No echo.");
            sensorStatus = currentRemoteStatus;  // ถ้าเซ็นเซอร์ error ให้ใช้สถานะเดิม
          } else {
            Serial.printf(" > Distance measured: %.1f cm\n", distance);
            sensorStatus = (distance < CAR_DETECT_THRESHOLD_CM) ? "occupied" : "available";
            Serial.printf(" > Determined Sensor Status: '%s'\n", sensorStatus.c_str());
          }

          // 4. อัปเดต Firebase ต่อเมื่อสถานะที่เซ็นเซอร์วัดได้ ไม่ตรงกับสถานะบนเซิร์ฟเวอร์
          if (sensorStatus != currentRemoteStatus) {
            Serial.println(" > Status has changed! Preparing to update Firebase...");
            String content = "{\"fields\": {\"status\": {\"stringValue\": \"" + sensorStatus + "\"}}}";

            if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.c_str(), "status")) {
              Serial.println("   - SUCCESS: Firebase updated.");
              lastSentStatus = sensorStatus;  // อัปเดตสถานะในเครื่องหลังส่งสำเร็จ
            } else {
              Serial.printf("   - FAILED to update: %s\n", fbdo.errorReason().c_str());
            }
          } else {
            Serial.println(" > Status has not changed. No update needed.");
          }
        }
      } else {
        Serial.println(" > Failed to parse status from Firebase response.");
      }
    } else {
      Serial.printf(" > FAILED to get document from Firebase: %s\n", fbdo.errorReason().c_str());
    }

    delay(2000);  // หน่วงเวลาก่อนเริ่มรอบใหม่

  } else {
    Serial.println("Waiting for Firebase sign-in...");
    delay(2000);
  }
}