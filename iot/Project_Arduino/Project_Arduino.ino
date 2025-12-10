/**
 * โปรเจกต์: Smart Parking IoT System (ESP32)
 * รายละเอียด: โค้ดสำหรับควบคุมอุปกรณ์ IoT ตรวจจับรถยนต์และส่งข้อมูลขึ้น Firebase
 */

#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "ArduinoJson.h"
#include <Preferences.h>

// 1. ส่วนตั้งค่าการเชื่อมต่อ (CONFIGURATION)

// กำหนดชื่อ Wifi และรหัสผ่านเริ่มต้น (กรณีไม่มีการตั้งค่าใหม่ผ่าน Serial Monitor)
String wifi_ssid = "WiFi Name";
String wifi_pass = "WiFi Password";

// การตั้งค่า Firebase Project
#define FIREBASE_API_KEY "Firebase API Key"          // คีย์ API ของ Firebase Project
#define FIREBASE_PROJECT_ID "Firebase Project ID"    // ชื่อ Project ID
#define USER_EMAIL "Firebase IOT User Email"         // อีเมลสำหรับ Authentication ของอุปกรณ์
#define USER_PASSWORD "Firebase IOT User Password"   // รหัสผ่านสำหรับ Authentication ของอุปกรณ์

// 2. ส่วนตั้งค่าฮาร์ดแวร์ (HARDWARE SETTINGS)

#define PARKING_SPOT_ID "1"            // รหัสระบุตำแหน่งช่องจอด (ต้องตรงกับใน Database)
const int CAR_DETECT_THRESHOLD_CM = 75; // ระยะทาง (cm) ที่จะถือว่ามีรถจอดอยู่ (ถ้าน้อยกว่าค่านี้ = มีรถ)
const int TRIG_PIN = 5;                // ขา Trigger ของเซ็นเซอร์ Ultrasonic
const int ECHO_PIN = 18;               // ขา Echo ของเซ็นเซอร์ Ultrasonic
const int LED_PIN = 2;                 // ขาไฟ LED แสดงสถานะ (ติด = มีรถ, ดับ = ว่าง)

// 3. ตัวแปรระบบและการจัดการข้อมูล (SYSTEM VARIABLES)

// ตัวแปรสำหรับไลบรารี Firebase
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
Preferences preferences; // ตัวแปรสำหรับบันทึกข้อมูลลงหน่วยความจำเครื่อง (ใช้เก็บ Wifi ล่าสุด)

// ตัวแปรเก็บสถานะการทำงาน
String localSensorStatus = "available"; // สถานะปัจจุบันที่วัดได้จากเซ็นเซอร์ ("available" หรือ "occupied")
String lastSentStatus = "available";    // สถานะล่าสุดที่ส่งขึ้น Firebase ไปแล้ว (เพื่อนำมาเทียบไม่ให้ส่งซ้ำ)
bool isUnavailable = false;             // ตัวแปรเช็คว่าช่องนี้ถูก Admin ปิดใช้งานหรือไม่
bool lastWifiState = false;             // ตัวแปรเก็บสถานะ Wifi รอบก่อนหน้า (เพื่อเช็คว่าเน็ตหลุด/กลับมา)

// ตัวแปรสำหรับจับเวลาการทำงาน (Non-blocking delay)
unsigned long lastSensorRead = 0;       // เวลาล่าสุดที่อ่านค่าเซ็นเซอร์
unsigned long lastFirebaseCheck = 0;    // เวลาล่าสุดที่เช็คสถานะจาก Firebase
const long SENSOR_INTERVAL = 500;       // อ่านค่าเซ็นเซอร์ทุกๆ 0.5 วินาที
const long FIREBASE_CHECK_INTERVAL = 10000; // เช็คข้อมูลจาก Server ทุกๆ 10 วินาที

// 4. ฟังก์ชันอ่านระยะทาง (HELPER FUNCTIONS)

/**
 * ฟังก์ชันอ่านค่าจาก Ultrasonic Sensor และแปลงเป็นระยะทางหน่วยเซนติเมตร
 * @return float ระยะทาง (cm) หรือ NAN หากอ่านค่าไม่ได้
 */
float readDistanceCM(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  // วัดความยาวคลื่นเสียงสะท้อนกลับ (หน่วย Microseconds)
  unsigned long us = pulseIn(echoPin, HIGH, 30000UL); // Timeout 30ms ถ้าเกินถือว่าวัดไม่ได้
  
  if (us == 0) return NAN; // อ่านค่าผิดพลาด
  return us * 0.01715;     // คำนวณเป็น cm (ความเร็วเสียงในอากาศประมาณ 343 m/s)
}

// 5. ฟังก์ชันจัดการคำสั่งตั้งค่าผ่าน Serial Monitor (SERIAL COMMANDS)

/**
 * ฟังก์ชันตรวจสอบคำสั่งที่พิมพ์เข้ามาผ่าน Serial Monitor สำหรับเปลี่ยน Wifi
 * รูปแบบ: 'ssid:ชื่อไวไฟ' หรือ 'pass:รหัสผ่าน'
 */
void checkSerialCommand() {
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim(); // ตัดช่องว่างหัวท้ายออก

    // กรณีเปลี่ยนชื่อ Wifi
    if (input.startsWith("ssid:")) {
      String newSSID = input.substring(5);
      if (newSSID.length() > 0) {
        preferences.begin("wifi-config", false); // เปิดโหมดเขียน
        preferences.putString("ssid", newSSID);  // บันทึกลง Memory
        preferences.end();
        Serial.println("\n[Config] SSID updated to: " + newSSID);
        Serial.println("[Config] Restarting to apply changes...");
        delay(1000);
        ESP.restart(); // รีสตาร์ทเครื่องเพื่อให้ใช้ค่าใหม่
      }
    } 
    // กรณีเปลี่ยนรหัสผ่าน
    else if (input.startsWith("pass:")) {
      String newPass = input.substring(5);
      if (newPass.length() > 0) {
        preferences.begin("wifi-config", false); 
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

// 6. การทำงานเริ่มต้น (SETUP)

void setup() {
  Serial.begin(115200);
  Serial.println("\n\n--- Starting Smart Parking System ---");

  // 1. โหลดค่า Wifi ที่เคยบันทึกไว้ใน Memory (ถ้ามี)
  preferences.begin("wifi-config", true); // โหมดอ่านอย่างเดียว
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

  // 2. ตั้งค่าขาอุปกรณ์ (Pins)
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW); // เริ่มต้นปิดไฟ

  // 3. เริ่มต้นเชื่อมต่อ Wifi
  Serial.println("[WiFi] Connecting to " + wifi_ssid + "...");
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());

  unsigned long startAttemptTime = millis();

  // วนลูปรอการเชื่อมต่อสูงสุด 10 วินาที
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 10000) {
    delay(500);
    Serial.print(".");
  }

  // แจ้งผลการเชื่อมต่อ
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] Connected successfully!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n[WiFi] Timeout! Internet not found.");
    Serial.println("[System] Activating OFFLINE MODE.");
    Serial.println("[System] Sensor will work, but data won't sync until WiFi returns.");
  }

  // 4. ตั้งค่าเตรียมเชื่อมต่อ Firebase (Library จะจัดการ Reconnect ให้เองเมื่อมีเน็ต)
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.timeout.serverResponse = 5000; 
  config.timeout.wifiReconnect = 1000;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true); // อนุญาตให้ต่อ Wifi ใหม่เองได้
  
  Serial.println("[System] Setup Complete.");
}

// 7. การทำงานวนลูปหลัก (LOOP)

void loop() {
  unsigned long currentMillis = millis();

  // 1. ตรวจสอบว่ามีคำสั่งตั้งค่า Wifi เข้ามาทาง Serial หรือไม่
  checkSerialCommand();

  // 2. ตรวจสอบสถานะ Wifi เพื่อแสดงข้อความแจ้งเตือนเมื่อหลุด/ต่อติด
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

  // 3. อ่านค่าเซ็นเซอร์ (Block นี้ทำงานตามรอบเวลา SENSOR_INTERVAL)
  if (currentMillis - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = currentMillis;

    // ถ้า Admin สั่งปิดช่องจอด -> ไม่ต้องอ่านเซ็นเซอร์ และปิดไฟ LED
    if (isUnavailable) {
       digitalWrite(LED_PIN, LOW);
       return; 
    }

    // อ่านระยะทางจริง
    float distance = readDistanceCM(TRIG_PIN, ECHO_PIN);
    
    // ถ้าอ่านค่าได้ถูกต้อง
    if (!isnan(distance)) {
      // ตีความระยะทาง: ถ้าน้อยกว่า Threshold = มีรถ (occupied), มากกว่า = ว่าง (available)
      String newStatus = (distance < CAR_DETECT_THRESHOLD_CM) ? "occupied" : "available";

      // ถ้าสถานะเปลี่ยนไปจากรอบที่แล้ว ให้แสดงผลออก Serial Monitor
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

      localSensorStatus = newStatus; // อัปเดตสถานะปัจจุบัน

      // คุมไฟ LED
      if (distance < CAR_DETECT_THRESHOLD_CM) {
        digitalWrite(LED_PIN, HIGH); // ไฟติด
      } else {
        digitalWrite(LED_PIN, LOW);  // ไฟดับ
      }
    }
  }

  // 4. ซิงค์ข้อมูลกับ Firebase (ทำงานเมื่อต่อเน็ตและ Firebase พร้อม)
  if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
    
    // 4.1 เช็คสถานะจาก Server (Admin สั่งปิดใช้งานหรือไม่?) ทำงานตามรอบ FIREBASE_CHECK_INTERVAL
    if (currentMillis - lastFirebaseCheck >= FIREBASE_CHECK_INTERVAL) {
      lastFirebaseCheck = currentMillis;
      String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
      
      // ดึงข้อมูล Document จาก Firestore
      if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str())) {
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, fbdo.payload());
        
        // ถ้าดึงสำเร็จและมีค่า status
        if (!error && doc["fields"]["status"]["stringValue"]) {
          String remoteVal = String(doc["fields"]["status"]["stringValue"]);
          
          // เช็คว่า Admin สั่งปิด (unavailable) หรือไม่
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

    // 4.2 ส่งสถานะเซ็นเซอร์ขึ้น Cloud (ส่งเมื่อค่าเปลี่ยน และช่องจอดไม่ได้ถูกปิดอยู่)
    if (localSensorStatus != lastSentStatus && !isUnavailable) {
      Serial.print("[Sync] Updating Firebase (" + localSensorStatus + ")... ");
      
      String documentPath = "parking_spots/" + String(PARKING_SPOT_ID);
      String content = "{\"fields\": {\"status\": {\"stringValue\": \"" + localSensorStatus + "\"}}}";
      
      // สั่ง Patch ข้อมูลขึ้น Firestore
      if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.c_str(), "status")) {
         Serial.println("SUCCESS!");
         lastSentStatus = localSensorStatus; // จำค่าล่าสุดที่ส่งสำเร็จ กันส่งซ้ำ
      } else {
         Serial.print("FAILED! Reason: ");
         Serial.println(fbdo.errorReason());
      }
    }
  }
}