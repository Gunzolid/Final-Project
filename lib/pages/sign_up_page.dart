// lib/pages/sign_up_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/services/notification_service.dart';

// =================================================================================
// หน้าสมัครสมาชิก (SIGN UP PAGE)
// =================================================================================

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSubmitting = false; // สถานะกำลังส่งข้อมูล
  String errorText = ''; // ข้อความ Error ที่แสดงผล

  // ฟังก์ชันสมัครสมาชิก
  Future<void> _signUp() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return; // กรอกข้อมูลไม่ครบหรือผิดรูปแบบ
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isSubmitting = true;
      errorText = '';
    });

    try {
      // 1. สร้าง Account ใน Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2. บันทึกข้อมูลโปรไฟล์ลง Firestore (users collection)
      final uid = userCredential.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'role': 'user', // กำหนด Role เริ่มต้นเป็น User ทั่วไป
      });

      // 3. อัปเดต Display Name ใน Auth Profile
      await userCredential.user!.updateDisplayName(name);

      // 4. ส่งอีเมลแจ้งเตือน (Welcome Email)
      FirebaseService().sendUserNotificationEmail(email: email, type: 'signup');

      // 5. บันทึก Token สำหรับแจ้งเตือน (FCM)
      await NotificationService().saveTokenToUser(uid);

      // 6. สมัครเสร็จแล้วพาไปหน้า Home ทันที (ล้าง Stack เดิมทิ้ง)
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      setState(() {
        // แสดงข้อความ Error ภาษาไทย (ถ้าทำได้) หรือใช้ message จาก Firebase
        errorText = e.message ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ปุ่มย้อนกลับ
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Sign up",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  // ช่องกรอกชื่อ
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อผู้ใช้',
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอกชื่อ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ช่องกรอกอีเมล
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Gmail',
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'กรุณากรอกอีเมล';
                      }
                      if (!EmailValidator.validate(email)) {
                        return 'อีเมลไม่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ช่องกรอกรหัสผ่าน
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 6) {
                        return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ช่องยืนยันรหัสผ่าน
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'รหัสผ่านไม่ตรงกัน';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ข้อความ Error
                  if (errorText.isNotEmpty)
                    Text(errorText, style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 20),

                  // ปุ่มสมัครสมาชิก
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          _isSubmitting
                              ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Sign up',
                                style: TextStyle(color: Colors.black),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
