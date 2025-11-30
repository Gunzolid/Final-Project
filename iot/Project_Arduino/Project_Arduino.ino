#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "ArduinoJson.h"


// 1. ส่วนตั้งค่าการเชื่อมต่อ (CONFIGURATION)
// 1.1 ตั้งค่า Wi-Fi *Importance*
const char* WIFI_SSID = "Your Wifi SSID";
const char* WIFI_PASSWORD = "Your Wifi Password";

// 1.2 ตั้งค่า Firebase Project
#define FIREBASE_API_KEY "Your Firebase API Key"
#define FIREBASE_PROJECT_ID "Your Firebase Project ID"

// 1.3 ตั้งค่าบัญชีผู้ใช้ (Authentication)
#define USER_EMAIL "Your Firebase User Email for IOT"
#define USER_PASSWORD "Your Firebase User Password for IOT"


// 2. ส่วนตั้งค่าฮาร์ดแวร์และเซ็นเซอร์ (HARDWARE)
#define PARKING_SPOT_ID "1"           // ระบุ ID ของช่องจอดนี้
const int CAR_DETECT_THRESHOLD_CM = 120; // ระยะทางที่จะถือว่า "มีรถจอด" (cm)
const int TRIG_PIN = 5;               // ขา Trigger ของ Ultrasonic
const int ECHO_PIN = 18;              // ขา Echo ของ Ultrasonic
const int LED_PIN = 2;                // ไฟ LED แสดงสถานะ

// 3. ตัวแปรระบบ (GLOBAL VARIABLES)
// ตัวแปรสำหรับ Firebase
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool firebaseReady = false;

// ตัวแปรสำหรับจัดการเวลา (Multitasking)
unsigned long lastSensorRead = 0;
unsigned long lastFirebaseCheck = 0;
const long SENSOR_INTERVAL = 1000;        // อ่านเซ็นเซอร์ทุก 1 วินาที
const long FIREBASE_CHECK_INTERVAL = 1000; // เช็คคำสั่งจาก Server ทุก 1 วินาที

// ตัวแปรเก็บสถานะปัจจุบัน
String currentRemoteStatus = "available"; // สถานะล่าสุดที่ Server รับรู้
bool isUnavailable = false;               // สถานะล็อคช่องจอด (จาก Admin)


// 4. ฟังก์ชันเสริม (HELPER FUNCTIONS)
// ฟังก์ชันอ่านค่าระยะทางจาก Ultrasonic (หน่วย cm)
float readDistanceCM(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  unsigned long us = pulseIn(echoPin, HIGH, 30000UL); // Timeout 30ms
  if (us == 0) return NAN; // อ่านค่าไม่ได้

  return us * 0.01715;
}


// 5. การทำงานหลัก (MAIN PROGRAM)
void setup() {
  Serial.begin(115200);

  // ตั้งค่า Pin เซ็นเซอร์
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);

  digitalWrite(TRIG_PIN, LOW);
  digitalWrite(LED_PIN, LOW);
  
  // เชื่อมต่อ Wi-Fi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("Connected IP: ");
  Serial.println(WiFi.localIP());

  // ตั้งค่า Firebase
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  // ตรวจสอบสถานะการเชื่อมต่อ Firebase
  if (Firebase.ready() && !firebaseReady) {
    Serial.println(">>> Firebase Initialized & Ready!");
    firebaseReady = true;
  }

  // หาก Firebase ยังไม่พร้อม ให้ข้ามการทำงานรอบนี้ไปก่อน
  if (!firebaseReady) return;

  unsigned long currentMillis = millis();


  // ตรวจสอบสถานะจาก Server (ทำทุกๆ 10 วินาที)
  if (currentMillis - lastFirebaseCheck >= FIREBASE_CHECK_INTERVAL) {
    lastFirebaseCheck = currentMillis;
    String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
    
    Serial.print("[TASK 1] Checking remote status... ");
    
    // ดึงข้อมูลจาก Firestore
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str())) {
      StaticJsonDocument<256> doc;
      deserializeJson(doc, fbdo.payload());
      
      // ดึงค่า status ออกมาเช็ค
      if (doc["fields"]["status"]["stringValue"]) {
        const char* remoteVal = doc["fields"]["status"]["stringValue"];
        currentRemoteStatus = String(remoteVal);
        Serial.printf("Current DB Status: %s\n", currentRemoteStatus.c_str());
        
        // อัปเดตตัวแปร flag ว่าช่องจอดปิดปรับปรุงหรือไม่
        if (currentRemoteStatus == "unavailable") {
          isUnavailable = true;
        } else {
          isUnavailable = false;
        }
      }
    } else {
      Serial.printf("Error reading DB: %s\n", fbdo.errorReason().c_str());
    }
  }


  // อ่านเซ็นเซอร์และอัปเดตข้อมูล (ทำทุกๆ 1 วินาที)
  if (currentMillis - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = currentMillis;

    // ถ้า Admin สั่งปิด (Unavailable) ให้ข้ามการอ่านเซ็นเซอร์
    if (isUnavailable) {
      Serial.println("[TASK 2] Spot unavailable. Skipping sensor.");
      digitalWrite(LED_PIN, LOW);
      return; 
    }

    // อ่านค่าเซ็นเซอร์
    float distance = readDistanceCM(TRIG_PIN, ECHO_PIN);
    
    if (isnan(distance)) {
       Serial.println("[TASK 2] Sensor Error: No reading.");
       return;
    }

    // ตีความสถานะจากระยะทาง
    String sensorStatus = (distance < CAR_DETECT_THRESHOLD_CM) ? "occupied" : "available";
    
    if (sensorStatus == "occupied") {
      digitalWrite(LED_PIN, HIGH); // มีรถจอด -> ไฟติด
    } else {
      digitalWrite(LED_PIN, LOW);  // ไม่มีรถ -> ไฟดับ
    }

    // เปรียบเทียบ: ถ้าสถานะใหม่ ไม่ตรงกับสิ่งที่ Server รู้อยู่ -> ให้อัปเดต
    if (sensorStatus != currentRemoteStatus) {
      Serial.printf("[UPDATE] Status Changed: %s -> %s. Updating Firebase...\n", currentRemoteStatus.c_str(), sensorStatus.c_str());
      
      String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
      // สร้าง JSON สำหรับ Patch ข้อมูล
      String content = "{\"fields\": {\"status\": {\"stringValue\": \"" + sensorStatus + "\"}}}";
      
      // ส่งข้อมูลขึ้น Firebase (Patch)
      if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.c_str(), "status")) {
         Serial.println("   >>> Update Success!");
         currentRemoteStatus = sensorStatus; // อัปเดตค่าในเครื่องทันทีเพื่อไม่ให้ส่งซ้ำ
      } else {
         Serial.printf("   >>> Update Failed: %s\n", fbdo.errorReason().c_str());
      }
    }
  }
}