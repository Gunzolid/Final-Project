import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// 1. อัปเกรด Class ให้เก็บข้อมูลสถานะได้
class RecommendationStatus {
  final bool isActive;
  final String? spotStatus; // สถานะปัจจุบัน e.g., 'held', 'occupied'
  final String? reason;

  RecommendationStatus({required this.isActive, this.spotStatus, this.reason});
}

class FirebaseParkingService {
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getParkingSpotsStream() {
    return _firestore.collection('parking_spots').snapshots();
  }

  Future<void> updateParkingStatus(
    String docId,
    Map<String, dynamic> dataToUpdate,
  ) {
    // เพิ่มการตรวจสอบเบื้องต้น (Optional)
    if (dataToUpdate.isEmpty) {
      return Future.value(); // ถ้าไม่มีข้อมูลให้อัปเดต ก็ไม่ต้องทำอะไร
    }
    // ใช้ dataToUpdate ในการอัปเดต
    return _firestore
        .collection('parking_spots')
        .doc(docId)
        .update(dataToUpdate);
  }

  // 2. ปรับปรุง Logic การติดตามสถานะให้ฉลาดขึ้น
  Stream<RecommendationStatus> watchRecommendation(int spotId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(
        RecommendationStatus(isActive: false, reason: 'User not logged in'),
      );
    }

    return _firestore.collection('parking_spots').doc('$spotId').snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        return RecommendationStatus(
          isActive: false,
          reason: 'ช่องจอดไม่มีอยู่แล้ว',
        );
      }
      final data = doc.data()!;
      final holdBy = data['hold_by'];
      final holdUntil = data['hold_until'] as Timestamp?;
      final currentStatus = data['status'] as String?;

      // *** เงื่อนไขใหม่: ถ้าช่องจอดถูกใช้งานแล้ว ถือว่าการจองสำเร็จและสิ้นสุดลง ***
      if (currentStatus == 'occupied') {
        return RecommendationStatus(
          isActive: false,
          spotStatus: 'occupied',
          reason: 'คุณเข้าจอดเรียบร้อยแล้ว',
        );
      }

      // เงื่อนไขเดิม: ถ้าการจองถูกยกเลิก
      if (holdBy != uid) {
        return RecommendationStatus(
          isActive: false,
          spotStatus: currentStatus,
          reason: 'การจองถูกยกเลิก',
        );
      }

      // เงื่อนไขเดิม: ถ้าการจองหมดเวลา
      if (holdUntil != null && Timestamp.now().compareTo(holdUntil) > 0) {
        return RecommendationStatus(
          isActive: false,
          spotStatus: currentStatus,
          reason: 'การจองหมดเวลา',
        );
      }

      // ถ้ายังไม่เข้าเงื่อนไขไหนเลย แสดงว่าการจองยังดำเนินอยู่
      return RecommendationStatus(isActive: true, spotStatus: currentStatus);
    });
  }

  Future<void> holdParkingSpot(int spotId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User is not logged in');
    }
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

  Future<void> cancelHold(int spotId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User is not logged in');
    }

    final spotRef = _firestore
        .collection('parking_spots')
        .doc(spotId.toString());

    try {
      // ใช้ transaction เพื่อความปลอดภัย
      await _firestore.runTransaction((transaction) async {
        final spotSnapshot = await transaction.get(spotRef);

        if (!spotSnapshot.exists) {
          throw Exception('Spot does not exist');
        }

        final data = spotSnapshot.data();
        // ตรวจสอบว่าเป็นผู้จองคนปัจจุบันจริงหรือไม่
        if (data != null &&
            data['hold_by'] == uid &&
            data['status'] == 'held') {
          transaction.update(spotRef, {
            'status': 'available', // คืนสถานะเป็นว่าง
            'hold_by': null, // ล้างข้อมูลผู้จอง
            'hold_until': null, // ล้างเวลาหมดอายุ
          });
          debugPrint('Hold cancelled for spot $spotId by user $uid');
        } else {
          // ถ้าไม่ตรงเงื่อนไข (อาจจะถูกคนอื่นจองไปแล้ว หรือสถานะเปลี่ยนไปแล้ว) ก็ไม่ต้องทำอะไร
          debugPrint('Cancellation condition not met for spot $spotId');
        }
      });
    } catch (e) {
      debugPrint('Failed to cancel hold for spot $spotId: $e');
      rethrow; // ส่งต่อ Error ให้ UI จัดการ
    }
  }

  Future<void> updateAllSpotsStatus(String targetStatus) async {
    // ตรวจสอบว่าสถานะที่ต้องการถูกต้องหรือไม่ (Optional)
    if (targetStatus != 'available' && targetStatus != 'unavailable') {
      throw ArgumentError('Invalid target status provided.');
    }

    debugPrint('Attempting to set all spots to: $targetStatus');

    final spotsCollection = _firestore.collection('parking_spots');
    final WriteBatch batch = _firestore.batch(); // สร้าง Batch Write

    try {
      // 1. ดึงข้อมูล ID ของทุกช่องจอด
      final QuerySnapshot allSpotsSnapshot = await spotsCollection.get();

      // 2. วนลูปเพื่อเพิ่มคำสั่ง update ลงใน batch
      for (QueryDocumentSnapshot spotDoc in allSpotsSnapshot.docs) {
        final Map<String, dynamic> updateData = {
          'status': targetStatus,
          // ล้างค่าอื่นๆ ที่ไม่เกี่ยวข้องเมื่อตั้งเป็น available/unavailable
          'hold_by': null,
          'hold_until': null,
          'start_time': null,
        };
        batch.update(spotDoc.reference, updateData);
      }

      // 3. ส่งคำสั่งทั้งหมดใน batch ไปทำงานพร้อมกัน
      await batch.commit();
      debugPrint('All spots updated to: $targetStatus');
    } catch (e) {
      rethrow; // ส่งต่อ Error ให้ UI จัดการ
    }
  }
}
