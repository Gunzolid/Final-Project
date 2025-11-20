import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBootstrap {
  /// สร้าง users/{uid} ถ้ายังไม่มี โดย **ไม่** ใส่ role (ปล่อยให้ว่างคือ user ปกติ)
  static Future<void> ensureUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'role': 'user',
      });
    }
  }
}
