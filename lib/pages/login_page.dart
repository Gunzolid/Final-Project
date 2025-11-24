import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:mtproject/pages/sign_up_page.dart';
import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/services/user_bootstrap.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _navigated = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1) sign in + ใส่ timeout กันแอพค้าง
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _pass.text,
          )
          .timeout(const Duration(seconds: 12));

      // 2) สร้าง users/{uid} ถ้ายังไม่มี (จะไม่เขียน role ใด ๆ)
      await UserBootstrap.ensureUserDoc();

      // 3) อ่านบทบาท — ไม่มี role = user ปกติ, role == 'admin' = แอดมิน
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final isAdmin =
          (data['role']?.toString().toLowerCase().trim() == 'admin');

      // 4) นำทางครั้งเดียวตามบทบาท
      if (!_navigated && mounted) {
        _navigated = true;
        Navigator.of(context).pushNamedAndRemoveUntil(
          isAdmin ? '/admin' : '/home',
          (route) => false,
        );

        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null && email.isNotEmpty) {
          // Fire-and-forget – UI ไม่ต้องรอให้ Cloud Function ส่งอีเมลสำเร็จ
          FirebaseService().sendUserNotificationEmail(
            email: email,
            type: 'login',
          );
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
      if (!mounted) return;
      String displayError = 'เข้าสู่ระบบล้มเหลว: ${e.message ?? e.code}';
      if (e.code == 'user-not-found') {
        displayError = 'ไม่พบบัญชีผู้ใช้นี้ โปรดสมัครสมาชิกก่อน';
      } else if (e.code == 'wrong-password') {
        displayError = 'รหัสผ่านไม่ถูกต้อง';
      }
      setState(() => _errorMessage = displayError);
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
    // เปลี่ยน WillPopScope เป็น PopScope
    return PopScope(
      // 1. canPop: กำหนดว่าหน้าจอนี้อนุญาตให้ 'Pop' (ย้อนกลับ) ได้หรือไม่
      //    เนื่องจากคุณต้องการ 'ป้องกัน' การย้อนกลับตามปกติ จึงตั้งค่าเป็น false
      canPop: false,

      // 2. onPopInvoked: จะถูกเรียกเมื่อมีการพยายาม 'Pop' (เช่น กดปุ่มย้อนกลับ)
      //    ค่า didPop จะเป็น true หากการ Pop ถูกอนุญาตโดยระบบ (แต่เราตั้ง canPop เป็น false ไว้)
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // เพิ่ม dynamic result
        if (didPop) {
          return;
        }
        // ตรรกะการเปลี่ยนหน้ายังคงเดิม
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);

        // (Optional) คุณสามารถใช้ 'result' ตรงนี้ได้ หากหน้าจอนี้รับค่าคืน
        // print('Received result: $result');
      },

      // ส่วน Child (เนื้อหา) ยังคงเหมือนเดิม
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
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
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'กรุณากรอกอีเมล';
                      }
                      if (!EmailValidator.validate(email)) {
                        return 'รูปแบบอีเมลไม่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'กรุณากรอกรหัสผ่าน';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
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
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 20),
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

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                Navigator.pop(context); // Close dialog first
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ส่งอีเมลรีเซ็ตรหัสผ่านเรียบร้อยแล้ว โปรดตรวจสอบกล่องจดหมาย'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                  );
                }
              }
            },
            child: const Text('ส่ง'),
          ),
        ],
      ),
    );
  }
}
