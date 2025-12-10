// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // สำหรับตรวจสอบว่าเป็น Web หรือไม่ (kIsWeb)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/pages/login_page.dart';
import 'package:mtproject/pages/home_page.dart';
import 'package:mtproject/pages/admin/admin_root_page.dart';
import 'package:mtproject/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:mtproject/services/user_bootstrap.dart'; // Helper สำหรับสร้างข้อมูล User เบื้องต้น
import 'package:mtproject/services/theme_manager.dart'; // Helper จัดการ Theme (Dark/Light Mode)

// =================================================================================
// MAIN FUNCTION: จุดเริ่มต้นของโปรแกรม
// =================================================================================
void main() async {
  // 1. ตรวจสอบให้แน่ใจว่า Flutter Binding ถูกสร้างเรียบร้อยแล้วก่อนเริ่มทำงานอื่น
  WidgetsFlutterBinding.ensureInitialized();

  // 2. เริ่มต้นเชื่อมต่อ Firebase ตาม Platform (Web, Android, iOS)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. เตรียมระบบ Theme (โหลดค่าที่ผู้ใช้เคยตั้งไว้)
  await ThemeManager.initialize();

  // 4. เริ่มต้นระบบแจ้งเตือน (Notifications)
  // หมายเหตุ: ข้ามการทำงานส่วนนี้ถ้าเป็น Web เพราะใช้คนละวิธีการ
  if (!kIsWeb) {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // ถ้าผู้ใช้ล็อกอินอยู่แล้ว ให้บันทึก Token สำหรับส่งแจ้งเตือนทันที
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await notificationService.saveTokenToUser(user.uid);
    }
  }

  // 5. สั่งรันแอปพลิเคชัน
  runApp(const MyApp());
}

// =================================================================================
// MY APP WIDGET: วิดเจ็ตหลักของแอป
// =================================================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ใช้ ValueListenableBuilder เพื่อรอฟังค่า ThemeMode (Dark/Light) ที่เปลี่ยนไป
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false, // ปิดป้าย DOBUG มุมขวาบน
          // ตั้งค่า Theme แบบสว่าง (Light Mode)
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple, // สีหลักของแอป
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          // ตั้งค่า Theme แบบมืด (Dark Mode)
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          // โหมดปัจจุบันที่จะใช้ (Light, Dark หรือ System)
          themeMode: currentMode,

          // กำหนดเส้นทาง (Routes) สำหรับเปลี่ยนหน้า
          routes: {
            '/login': (_) => const LoginPage(),
            '/home': (_) => const HomePage(),
            '/admin': (_) => const AdminRootPage(),
          },

          // หน้าแรกที่จะแสดง (ตรวจสอบการล็อกอินก่อน)
          home: const AuthChecker(),
        );
      },
    );
  }
}

// =================================================================================
// AUTH CHECKER: ตัวตรวจสอบสถานะการเข้าสู่ระบบ
// =================================================================================
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  /// ฟังก์ชันสำหรับตรวจสอบสถานะและส่งคืนหน้าที่ควรจะไป
  Future<Widget> _getStartPage() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. ถ้ายังไม่ล็อกอิน ให้ไปที่หน้า HomePage (Guest Mode) หรือ LoginPage ก็ได้
    // ในที่นี้เลือกไป HomePage เพื่อให้ดู map ได้ก่อน
    if (user == null) {
      return const HomePage();
    }

    // 2. ถ้าล็อกอินแล้ว ตรวจสอบว่ามีข้อมูลใน Firestore หรือยัง (ถ้าไม่มีให้สร้าง)
    await UserBootstrap.ensureUserDoc();

    // 3. ตรวจสอบ Role ของผู้ใช้ (Admin หรือ User ทั่วไป)
    final uid = user.uid;
    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    // ดึงค่า role ถ้าไม่มีให้เป็น 'user'
    final role =
        docSnapshot.exists ? (docSnapshot.data()?['role'] ?? 'user') : 'user';

    // 4. ส่งคืนหน้าตาม Role
    if (role == 'admin') {
      return const AdminRootPage(); // ไปหน้า Admin
    } else {
      return const HomePage(); // ไปหน้า User ปกติ
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ FutureBuilder ในการรอผลการตรวจสอบสถานะ (Ascync)
    return FutureBuilder<Widget>(
      future: _getStartPage(),
      builder: (context, snapshot) {
        // กรณี: กำลังโหลด (Waiting)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // กรณี: เกิดข้อผิดพลาด (Error)
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้')),
          );
        }
        // กรณี: สำเร็จ (Has Data)
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        // Fallback: ถ้าหลุดเคสทั้งหมดให้ไปหน้า Login
        return const LoginPage();
      },
    );
  }
}
