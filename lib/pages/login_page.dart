// lib/pages/login_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mtproject/pages/sign_up_page.dart';
import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/services/user_bootstrap.dart';
import 'package:mtproject/services/notification_service.dart';

// =================================================================================
// หน้าเข้าสู่ระบบ (LOGIN PAGE)
// =================================================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false; // สถานะการโหลด (กันกดซ้ำ)
  bool _navigated = false; // ป้องกันการเปลี่ยนหน้าซ้ำซ้อน
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ฟังก์ชันกดปุ่ม Login
  Future<void> _onLogin() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) {
      return; // ถ้าฟอร์มไม่ผ่าน (เช่น อีเมลผิดรูปแบบ) ไม่ทำต่อ
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1) สั่ง Sign In ผ่าน Firebase Auth
      //    ใส่ timeout 12 วินาที ป้องกันแอพค้างนานเกินไปหากเน็ตไม่ดี
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _pass.text,
          )
          .timeout(const Duration(seconds: 12));

      // 2) ตรวจสอบและสร้างเอกสารผู้ใช้ใน Firestore (users/{uid}) หากยังไม่มี
      //    (สำคัญมากสำหรับ user เก่าที่อาจจะยังไม่มี doc)
      await UserBootstrap.ensureUserDoc();

      // 3) อ่าน Role ของผู้ใช้เพื่อพาไปหน้าจอที่ถูกต้อง
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final isAdmin =
          (data['role']?.toString().toLowerCase().trim() == 'admin');

      // 4) พาไปหน้าถัดไป (Home หรือ Admin)
      if (!_navigated && mounted) {
        _navigated = true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          isAdmin ? '/admin' : '/home',
          (route) => false, // ลบประวัติการย้อนกลับทั้งหมด
        );

        // ส่งอีเมลแจ้งเตือนการ Login (Optional Feature)
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null && email.isNotEmpty) {
          FirebaseService().sendUserNotificationEmail(
            email: email,
            type: 'login',
          );
        }

        // บันทึก FCM Token ลงใน Firestore เพื่อรับการแจ้งเตือน
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          NotificationService().saveTokenToUser(user.uid);
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เครือข่ายช้าหรือ Firebase ไม่ตอบสนอง ช่วยลองใหม่อีกครั้ง',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // จัดการ Error จาก Firebase Spec
      if (!mounted) return;
      String displayError = 'เข้าสู่ระบบล้มเหลว: ${e.message ?? e.code}';
      if (e.code == 'user-not-found') {
        displayError = 'ไม่พบบัญชีผู้ใช้นี้ โปรดสมัครสมาชิกก่อน';
      } else if (e.code == 'wrong-password') {
        displayError = 'รหัสผ่านไม่ถูกต้อง';
      }
      setState(() => _errorMessage = displayError);

      // ถ้าไม่มี User แนะนำให้สมัครสมาชิก
      if (e.code == 'user-not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayError),
            action: SnackBarAction(
              label: 'สมัครสมาชิก',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ PopScope เพื่อควบคุมการกดปุ่ม Back (Android)
    return PopScope(
      canPop: false, // ไม่อนุญาตให้ Pop ปกติ
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // บังคับให้กลับไปหน้า Home แทนการปิดแอพหรือย้อนกลับไปหน้าว่างเปล่า
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // ปุ่มย้อนกลับแบบกำหนดเอง (กลับไป Home)
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed:
                () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
          ),
          title: const Text('เข้าสู่ระบบ'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ช่องกรอกอีเมล
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'กรุณากรอกอีเมล';
                      if (!EmailValidator.validate(email))
                        return 'รูปแบบอีเมลไม่ถูกต้อง';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // ช่องกรอกรหัสผ่าน
                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'กรุณากรอกรหัสผ่าน';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ปุ่มลืมรหัสผ่าน
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('ลืมรหัสผ่าน?'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // แสดงข้อความ Error (ถ้ามี)
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 20),

                  // ปุ่ม Login
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),

                  const SizedBox(height: 12),
                  // ปุ่มไปหน้าสมัครสมาชิก
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    child: const Text('สร้างบัญชีใหม่'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dialog ลืมรหัสผ่าน (ส่งอีเมล Reset)
  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ลืมรหัสผ่าน'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('กรุณากรอกอีเมลเพื่อรับลิงก์รีเซ็ตรหัสผ่าน'),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('กรุณากรอกอีเมล')),
                    );
                    return;
                  }
                  try {
                    Navigator.pop(context); // ปิด Dialog ก่อนทำงาน
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email,
                    );

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'ส่งอีเมลรีเซ็ตรหัสผ่านเรียบร้อยแล้ว โปรดตรวจสอบกล่องจดหมาย',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                    );
                  }
                },
                child: const Text('ส่ง'),
              ),
            ],
          ),
    );
  }
}
