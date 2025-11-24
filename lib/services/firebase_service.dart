import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // อัปเดตข้อมูลโปรไฟล์ของผู้ใช้
  Future<void> updateUserProfile(String uid, String name) async {
    debugPrint(">>> Updating profile for UID: $uid");
    debugPrint(">>> New name to save: $name"); // ดูว่าค่า name ถูกต้องไหม
    try {
      await _firestore.collection('users').doc(uid).update({'name': name});
      debugPrint(">>> Successfully updated 'name' field.");
    } catch (e) {
      debugPrint(">>> Error updating profile: $e");
    }
  }

  // อัปเดตข้อมูลผู้ใช้แบบ Generic
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      debugPrint(">>> Successfully updated user data: $data");
    } catch (e) {
      debugPrint(">>> Error updating user data: $e");
      rethrow;
    }
  }

  // ดึงข้อมูลโปรไฟล์จาก Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "test_user";
    DocumentSnapshot doc =
        await _firestore.collection('users').doc(userId).get();

    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  Future<void> deleteUserData(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      debugPrint("User data deleted from Firestore for UID: $uid");
    } catch (e) {
      debugPrint("Error deleting user data from Firestore: $e");
      // อาจจะ rethrow หรือจัดการ error ตามความเหมาะสม
      rethrow;
    }
  }

  /// Deletes both the Firebase Auth user and the associated Firestore profile.
  ///
  /// Auth deletion is attempted first so that we never remove profile data when
  /// the SDK requires a recent login. Once the credential is cleared, the user
  /// document is removed using the stored UID.
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
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Bubble up so the caller can trigger a re-authentication flow.
        throw e;
      }
      rethrow;
    }

    await _firestore.collection('users').doc(uid).delete();
  }

  /// Returns true when the provided user document carries the admin role.
  Future<bool> isAdmin(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final role = (doc.data()?['role'] as String?)?.toLowerCase();
    return role == 'admin';
  }

  /// Triggers the Cloud Function that sends (stubbed) notification emails for
  /// login and signup events. The function currently only logs a message, but
  /// this keeps the client wired up for future integrations.
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
}
