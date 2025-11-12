import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// import 'package:mtproject/pages/home_page.dart';
// import 'package:mtproject/pages/admin_parking_page.dart'; // <-- ชื่อหน้าแอดมินของคุณ
import 'package:mtproject/pages/sign_up_page.dart';
import 'package:mtproject/services/user_bootstrap.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _navigated = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loading) return;
    setState(() => _loading = true);

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
        // ใช้ Navigator.pushReplacement เพื่อแทนที่หน้า Login ใน Stack
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder:
        //         (_) =>
        //             isAdmin
        //                 ? const AdminParkingPage()
        //                 : const HomePage(), // <-- ถ้าเป็น User ให้ไป Home
        //   ),
        Navigator.of(context).pushNamedAndRemoveUntil(
          isAdmin ? '/admin' : '/home',
          (route) => false,
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เข้าสู่ระบบล้มเหลว: ${e.message ?? e.code}')),
      );
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
    // return Scaffold(
    //   // VVV 1. เพิ่ม AppBar VVV
    //   appBar: AppBar(
    //     title: const Text('เข้าสู่ระบบ'),
    //     // เพิ่มปุ่มย้อนกลับที่มุมซ้ายบน
    //     leading: IconButton(
    //       icon: const Icon(Icons.arrow_back_ios),
    //       onPressed: () {
    //         // สั่ง pop เพื่อกลับไปยังหน้า Home ที่อยู่ข้างใต้
    //         Navigator.pop(context);
    //       },
    //     ),
    //     automaticallyImplyLeading: false, // ป้องกันการสร้างปุ่มย้อนกลับซ้ำซ้อน
    //   ),
    //   // ^^^ สิ้นสุด AppBar ^^^

    //   // VVV 2. ย้าย body VVV
    //   body: Center(
    //     child: ConstrainedBox(
    //       constraints: const BoxConstraints(maxWidth: 320),
    //       child: Column(
    //         mainAxisSize: MainAxisSize.min,
    //         children: [
    //           TextField(
    //             controller: _email,
    //             keyboardType: TextInputType.emailAddress,
    //             decoration: const InputDecoration(labelText: 'Email'),
    //           ),
    //           const SizedBox(height: 12),
    //           TextField(
    //             controller: _pass,
    //             obscureText: true,
    //             decoration: const InputDecoration(labelText: 'Password'),
    //           ),
    //           const SizedBox(height: 20),
    //           _loading
    //               ? const CircularProgressIndicator()
    //               : SizedBox(
    //                 width: double.infinity,
    //                 height: 44,
    //                 child: ElevatedButton(
    //                   onPressed: _onLogin,
    //                   style: ElevatedButton.styleFrom(
    //                     backgroundColor: Colors.grey[300],
    //                     shape: RoundedRectangleBorder(
    //                       borderRadius: BorderRadius.circular(10),
    return WillPopScope(
      onWillPop: () async {
        // ป้องกันการย้อนกลับไปยังสแต็คว่าง โดยพากลับไปหน้า Home แทน
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('เข้าสู่ระบบ'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
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
                      // child: const Text(
                      //   'Login',
                      //   style: TextStyle(color: Colors.black),
                    ),
                // ),
                //       ),
                //   const SizedBox(height: 12),
                //   TextButton(
                //     onPressed: () {
                //       // ถ้ามีการกดสมัครสมาชิก หน้า Login จะถูก Push ทับ
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(builder: (_) => const SignUpPage()),
                //       );
                //     },
                //     child: const Text('สร้างบัญชีใหม่'),
                //   ),
                // ],
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
    );
  }
}
