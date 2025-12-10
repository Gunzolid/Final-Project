import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBootstrap {
  /// ฟังก์ชันสำหรับสร้างข้อมูลผู้ใช้ (Document) ลงใน Firestore ในครั้งแรก
  /// (ใช้กรณีที่สมัครสมาชิกหรือล็อกอินครั้งแรกแล้วข้อมูลยังไม่มี)
  static Future<void> ensureUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    // ถ้ายังไม่มีข้อมูลใน Database ให้สร้างใหม่
    if (!snap.exists) {
      await ref.set({
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'role': 'user', // กำหนด Role เริ่มต้นเป็น 'user' เสมอ
      });
    }
  }
}
