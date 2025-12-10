import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mtproject/services/parking_functions.dart';

// =================================================================================
// MODELS และผลลัพธ์การทำงาน (HELPER CLASSES)
// =================================================================================

/// คลาสสำหรับเก็บสถานะการแนะนำช่องจอด (ใช้ใน Stream)
class RecommendationStatus {
  final bool isActive; // การจองยังดำเนินอยู่หรือไม่
  final String? spotStatus; // สถานะปัจจุบันของช่องจอด (held, occupied, etc.)
  final String? reason; // เหตุผลที่การจองสิ้นสุด (เช่น หมดเวลา, มีรถมาจอด)

  RecommendationStatus({required this.isActive, this.spotStatus, this.reason});
}

/// ผลลัพธ์จากการขอคำแนะนำช่องจอด
class RecommendationResult {
  final int spotId; // รหัสช่องจอดที่แนะนำ
  final bool reusedExistingHold; // เป็นการจองเดิมที่ยังไม่หมดเวลาใช่หรือไม่

  const RecommendationResult({
    required this.spotId,
    this.reusedExistingHold = false,
  });
}

class FirebaseParkingService {
  final _firestore = FirebaseFirestore.instance;

  // =================================================================================
  // การดึงข้อมูลเรียลไทม์ (REAL-TIME DATA STREAMS)
  // =================================================================================

  /// ดึงข้อมูลช่องจอดทั้งหมดแบบ Real-time
  Stream<QuerySnapshot<Map<String, dynamic>>> getParkingSpotsStream() {
    return _firestore.collection('parking_spots').snapshots();
  }

  /// ติดตามสถานะช่องจอดที่จองไว้แบบละเอียด (Smart Watch)
  /// ใช้สำหรับหน้าจอค้นหา เพื่อดูว่าจองสำเร็จไหม หรือหลุดการจองแล้ว
  Stream<RecommendationStatus> watchRecommendation(int spotId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(
        RecommendationStatus(isActive: false, reason: 'User not logged in'),
      );
    }

    return _firestore
        .collection('parking_spots')
        .doc('$spotId')
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return RecommendationStatus(
              isActive: false,
              reason: 'ช่องจอดไม่มีอยู่แล้ว',
            );
          }
          final data = doc.data()!;
          final holdBy = data['hold_by'];
          final holdUntil = data['hold_until'] as Timestamp?;
          final currentStatus = (data['status'] as String?)?.toLowerCase();

          // 1. ถ้าช่องจอดกลายเป็น occupied (มีรถจอด) -> ถือว่าสำเร็จจบงาน
          if (currentStatus == 'occupied') {
            return RecommendationStatus(
              isActive: false,
              spotStatus: 'occupied',
              reason: 'ช่องจอดถูกใช้งานแล้ว',
            );
          }

          // 2. ถ้าช่องจอดถูก Admin ปิดใช้งาน -> แจ้งเตือน
          if (currentStatus == 'unavailable') {
            return RecommendationStatus(
              isActive: false,
              spotStatus: 'unavailable',
              reason: 'ช่องถูกปิดใช้งาน โปรดลองค้นหาใหม่',
            );
          }

          // 3. ถ้าคนจองไม่ใช่เราแล้ว (โดนคนอื่นแย่งหรือระบบเคลียร์)
          if (holdBy != uid) {
            return RecommendationStatus(
              isActive: false,
              spotStatus: currentStatus,
              reason: 'การจองถูกยกเลิก',
            );
          }

          // 4. ถ้าเวลาจองหมดอายุ
          if (holdUntil != null && Timestamp.now().compareTo(holdUntil) > 0) {
            return RecommendationStatus(
              isActive: false,
              spotStatus: currentStatus,
              reason: 'การจองหมดเวลา',
            );
          }

          // 5. ถ้าปกติดี -> การจองยัง Active อยู่
          return RecommendationStatus(
            isActive: true,
            spotStatus: currentStatus,
          );
        });
  }

  // =================================================================================
  // การจัดการช่องจอด (SPOT MANAGEMENT ACTIONS)
  // =================================================================================

  /// อัปเดตข้อมูลช่องจอด (ทั่วไป)
  Future<void> updateParkingStatus(
    String docId,
    Map<String, dynamic> dataToUpdate,
  ) {
    if (dataToUpdate.isEmpty) {
      return Future.value();
    }
    return _firestore
        .collection('parking_spots')
        .doc(docId)
        .update(dataToUpdate);
  }

  /// จองช่องจอด (Client Side - ปกติจะใช้ผ่าน Cloud Function แต่มีไว้สำรอง)
  Future<void> holdParkingSpot(int spotId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User is not logged in');

    try {
      await _firestore
          .collection('parking_spots')
          .doc(spotId.toString())
          .update({
            'status': 'held',
            'hold_by': uid,
            'hold_until': Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 15)),
            ),
          });
      debugPrint('Spot $spotId held by user $uid');
    } catch (e) {
      debugPrint('Failed to hold spot $spotId: $e');
      rethrow;
    }
  }

  /// ยกเลิกการจอง (เช่น กดปุ่มยกเลิกในแอป)
  Future<void> cancelHold(int spotId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User is not logged in');

    final spotRef = _firestore
        .collection('parking_spots')
        .doc(spotId.toString());

    try {
      await _firestore.runTransaction((transaction) async {
        final spotSnapshot = await transaction.get(spotRef);
        if (!spotSnapshot.exists) throw Exception('Spot does not exist');

        final data = spotSnapshot.data();
        // ตรวจสอบว่าเป็นเจ้าของ booking จริงไหมก่อนลบ
        if (data != null &&
            data['hold_by'] == uid &&
            data['status'] == 'held') {
          transaction.update(spotRef, {
            'status': 'available',
            'hold_by': null,
            'hold_until': null,
          });
          debugPrint('Hold cancelled for spot $spotId by user $uid');
        } else {
          debugPrint('Cancellation condition not met for spot $spotId');
        }
      });
    } catch (e) {
      debugPrint('Failed to cancel hold for spot $spotId: $e');
      rethrow;
    }
  }

  /// อัปเดตสถานะทุกช่องจอดพร้อมกัน (Admin Bulk Action)
  Future<void> updateAllSpotsStatus(String targetStatus) async {
    if (targetStatus != 'available' && targetStatus != 'unavailable') {
      throw ArgumentError('Invalid target status provided.');
    }

    debugPrint('Attempting to set all spots to: $targetStatus');

    final spotsCollection = _firestore.collection('parking_spots');
    final WriteBatch batch = _firestore.batch();

    try {
      final QuerySnapshot allSpotsSnapshot = await spotsCollection.get();

      for (QueryDocumentSnapshot spotDoc in allSpotsSnapshot.docs) {
        final Map<String, dynamic> updateData = {
          'status': targetStatus,
          'hold_by': null,
          'hold_until': null,
          'start_time': null,
          'note': null,
        };
        batch.update(spotDoc.reference, updateData);
      }

      await batch.commit();
      debugPrint('All spots updated to: $targetStatus');
    } catch (e) {
      rethrow;
    }
  }

  // =================================================================================
  // ระบบค้นหาและแนะนำ (RECOMMENDATION SYSTEM)
  // =================================================================================

  /// ตรวจสอบว่าผู้ใช้มีการจองค้างไว้อยู่แล้วหรือไม่
  Future<int?> getActiveHeldSpotId(String uid) async {
    final query =
        await _firestore
            .collection('parking_spots')
            .where('hold_by', isEqualTo: uid)
            .limit(1)
            .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();
    final status = (data['status'] as String?)?.toLowerCase();
    final holdUntil = data['hold_until'] as Timestamp?;
    final now = Timestamp.now();

    // เช็คว่าหมดอายุหรือยัง
    final bool isExpired = holdUntil != null && now.compareTo(holdUntil) > 0;

    // ถ้าหมดอายุ หรือสถานะไม่ใช่ held แล้ว (เช่น administrator ไปเปลี่ยน) ให้เคลียร์ค่า
    if (isExpired || status != 'held') {
      await doc.reference.update({
        'status': 'available',
        'hold_by': null,
        'hold_until': null,
      });
      return null;
    }

    // แปลง ID เป็น int เพื่อส่งกลับ
    final dynamic rawId = data['id'];
    if (rawId is int) return rawId;
    if (rawId is String) return int.tryParse(rawId);

    return int.tryParse(doc.id);
  }

  /// ฟังก์ชันหลักสำหรับแนะนำช่องจอด (Client Helper)
  /// ใช้เรียก Cloud Function เพื่อหาช่องจอดให้อัตโนมัติ
  Future<RecommendationResult?> recommendAndHoldClient({
    int holdSeconds = 900, // ค่าเริ่มต้นจองไว้ 15 นาที
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User is not logged in');

    // 1. เช็คก่อนว่ามีจองค้างไว้ไหม ถ้ามีให้ใช้ของเดิม
    final existing = await getActiveHeldSpotId(uid);
    if (existing != null) {
      return RecommendationResult(spotId: existing, reusedExistingHold: true);
    }

    // 2. ถ้าไม่มี ให้เรียก Cloud Function หาช่องว่างที่ใกล้ที่สุด
    final result = await ParkingFunctions.recommend(holdSeconds: holdSeconds);
    if (result == null) {
      return null;
    }
    return RecommendationResult(spotId: result.id);
  }
}
