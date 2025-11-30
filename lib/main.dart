// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/pages/login_page.dart';
import 'package:mtproject/pages/home_page.dart';
import 'package:mtproject/pages/admin/admin_root_page.dart';
import 'package:mtproject/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:mtproject/services/user_bootstrap.dart'; // Import bootstrap
import 'package:mtproject/services/theme_manager.dart'; // Import theme_manager

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeManager.initialize();

  // เราจะย้ายการสร้างข้อมูลไปไว้ใน AuthChecker แทน
  // เพื่อให้แน่ใจว่ามันทำงานหลังจากมีคนล็อกอินแล้ว

  // Initialize Notification Service (Skip on Web for now)
  if (!kIsWeb) {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Get and save FCM token if user is already logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await notificationService.saveTokenToUser(user.uid);
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ใช้ ValueListenableBuilder เพื่อให้ Theme ทำงาน
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          // Theme สว่าง
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          // Theme มืด
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          themeMode: currentMode,
          routes: {
            '/login': (_) => const LoginPage(),
            '/home': (_) => const HomePage(),
            '/admin': (_) => const AdminRootPage(),
          },
          home: const AuthChecker(),
        );
      },
    );
  }
}

// ตรวจสอบว่า User ล็อกอินหรือยัง และเป็น admin หรือไม่
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  Future<Widget> _getStartPage() async {
    final user = FirebaseAuth.instance.currentUser;

    // =================================================================
    //  VVV      จุดแก้ไข: ถ้าไม่ล็อกอิน ให้ไป HomePage      VVV
    // =================================================================
    if (user == null) {
      return const HomePage(); // <-- ถ้ายังไม่ Login ให้ไปหน้า Home
    }
    // =================================================================

    // ถ้า Login แล้ว (user != null)
    // 1. สร้าง Document ของ User ใน Firestore ถ้ายังไม่มี
    await UserBootstrap.ensureUserDoc();

    // 2. เช็ค role ต่อ (เหมือนเดิม)
    final uid = user.uid;
    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final role =
        docSnapshot.exists ? (docSnapshot.data()?['role'] ?? 'user') : 'user';

    if (role == 'admin') {
      return const AdminRootPage();
    } else {
      return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้')),
          );
        }
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        // Fallback case (ถ้าเกิดข้อผิดพลาดร้ายแรง ให้ไปหน้า Login)
        return const LoginPage();
      },
    );
  }
}
