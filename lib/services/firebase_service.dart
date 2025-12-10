import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // =================================================================================
  // จัดการข้อมูลผู้ใช้ (USER PROFILE MANAGEMENT)
  // =================================================================================

  /// อัปเดตชื่อผู้ใช้ใน Firestore
  Future<void> updateUserProfile(String uid, String name) async {
    debugPrint(">>> Updating profile for UID: $uid");
    debugPrint(">>> New name to save: $name");
    try {
      await _firestore.collection('users').doc(uid).update({'name': name});
      debugPrint(">>> Successfully updated 'name' field.");
    } catch (e) {
      debugPrint(">>> Error updating profile: $e");
    }
  }

  /// ฟังก์ชันอัปเดตข้อมูลผู้ใช้แบบระบุข้อมูลเอง (Generic Update)
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      debugPrint(">>> Successfully updated user data: $data");
    } catch (e) {
      debugPrint(">>> Error updating user data: $e");
      rethrow;
    }
  }

  /// ดึงข้อมูลโปรไฟล์จาก Firestore โดยใช้ UID ปัจจุบัน
  Future<Map<String, dynamic>?> getUserProfile() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (userId.isEmpty) return null;

    DocumentSnapshot doc =
        await _firestore.collection('users').doc(userId).get();

    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  /// ลบข้อมูลผู้ใช้จาก Firestore (เฉพาะข้อมูลโปรไฟล์)
  Future<void> deleteUserData(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      debugPrint("User data deleted from Firestore for UID: $uid");
    } catch (e) {
      debugPrint("Error deleting user data from Firestore: $e");
      rethrow;
    }
  }

  /// ลบบัญชีผู้ใช้ถาวร (ลบทั้ง Authentication และ Firestore)
  /// หมายเหตุ: ต้องมีการ Login ล่าสุดไม่นานเกินไป มิฉะนั้นต้อง Re-authenticate ก่อน
  Future<void> deleteCurrentUserCompletely() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user is available for deletion.',
      );
    }

    final uid = user.uid;

    try {
      // 1. ลบบัญชี Auth ก่อน (เพื่อป้องกันการ Login ใหม่)
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // กรณี Login นานแล้ว ต้องแจ้งให้ผู้ใช้ Login ใหม่
      if (e.code == 'requires-recent-login') {
        rethrow;
      }
      rethrow;
    }

    // 2. ลบข้อมูลใน Firestore ตามหลัง
    await _firestore.collection('users').doc(uid).delete();
  }

  // =================================================================================
  // ตรวจสอบสิทธิ์และบทบาท (PERMISSIONS & ROLES)
  // =================================================================================

  /// ตรวจสอบว่าเป็น Admin หรือไม่
  Future<bool> isAdmin(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final role = (doc.data()?['role'] as String?)?.toLowerCase();
    return role == 'admin';
  }

  // =================================================================================
  // ฟังก์ชันอื่น ๆ (UTILITIES & CLOUD FUNCTIONS)
  // =================================================================================

  /// เรียก Cloud Function เพื่อส่งอีเมลแจ้งเตือน (Login/Signup)
  Future<void> sendUserNotificationEmail({
    required String email,
    required String type,
  }) async {
    try {
      await _functions.httpsCallable('sendUserNotificationEmail').call({
        'email': email,
        'type': type,
      });
    } catch (e, st) {
      debugPrint('sendUserNotificationEmail failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// บันทึก FCM Token สำหรับ Push Notification ลงในข้อมูลผู้ใช้
  Future<void> saveDeviceToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint(">>> FCM Token saved for user: ${user.uid}");
    } catch (e) {
      debugPrint(">>> Error saving FCM token: $e");
    }
  }
}
