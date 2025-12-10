// import 'dart:io'; // ไม่ใช้ dart:io เพราะไม่รองรับบน Web
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =================================================================================
// BACKGROUND HANDLER: ทำงานเมื่อแอปถูกปิดหรือล็อกหน้าจอ
// =================================================================================

// ฟังก์ชันนี้ต้องอยู่ระดับ Top-level (นอก Class) เพื่อให้ทำงานได้แม้แอปปิดอยู่
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  // ถ้าต้องการเรียกใช้ Firebase Service อื่นๆ ในนี้ ต้อง Initialize Firebase ใหม่ก่อนเสมอ
}

// =================================================================================
// NOTIFICATION SERVICE: จัดการระบบแจ้งเตือนทั้งหมด
// =================================================================================

class NotificationService {
  // สร้าง Singleton Instance เพื่อให้เรียกใช้ได้ทั่วแอพโดยไม่ต้องสร้าง Object ใหม่
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false; // ตัวแปรเช็คว่าเริ่มทำงานหรือยัง

  /// ฟังก์ชันเริ่มต้นระบบ (ควรเรียกตอนเปิดแอป)
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. ขออนุญาตแจ้งเตือน (Request Permission)
    // สำหรับ iOS และ Android 13+ จะมี Popup เด้งขอสิทธิ์
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
      // ถ้าไม่อนุญาต ก็หยุดการทำงานส่วนแจ้งเตือนไปเลย
      return;
    }

    // 2. ตั้งค่า Local Notifications (สำหรับการแสดงผลตอนเปิดแอปอยู่)
    if (!kIsWeb) {
      // ตั้งค่าไอคอนสำหรับ Android (ต้องมีไฟล์รูปใน android/app/src/main/res/drawable)
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications.initialize(initializationSettings);
    }

    // 3. ลงทะเบียน Background Handler (สำหรับตอนปิดแอป)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. ดักจับข้อความตอนเปิดแอปอยู่ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      // ถ้ามีข้อมูลแจ้งเตือน ให้แสดง Local Notification ทับลงไป
      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      }
    });

    _isInitialized = true;
  }

  /// ดึง Token ของเครื่อง (FCM Token) เพื่อใช้ส่งแจ้งเตือนแบบระบุเครื่อง
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// บันทึก Token ลงในข้อมูลผู้ใช้บน Firestore
  /// (เพื่อให้เซิร์ฟเวอร์รู้ว่าต้องส่งหาใคร)
  Future<void> saveTokenToUser(String uid) async {
    final token = await getToken();
    if (token == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'last_token_update': FieldValue.serverTimestamp(),
      });
      debugPrint("FCM Token saved for user $uid");
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }

  /// ฟังก์ชันแสดงแจ้งเตือนแบบ Local (ใช้ตอนเปิดแอปอยู่)
  void _showLocalNotification(RemoteMessage message) {
    if (kIsWeb) return; // Web ไม่รองรับวิธีนี้

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // ต้องตรงกับที่ตั้งใน AndroidManifest
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }
}
