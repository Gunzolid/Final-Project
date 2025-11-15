// lib/models/admin_parking_box.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/services/firebase_parking_service.dart';

class AdminParkingBox extends StatelessWidget {
  // ยังคงเป็น StatelessWidget
  final String docId;
  final int id;
  final Axis direction;

  const AdminParkingBox({
    // <-- ใช้ const constructor ได้
    super.key,
    required this.docId,
    required this.id,
    this.direction = Axis.vertical,
  });

  // ฟังก์ชันหา status ถัดไป (ย้ายมาไว้ข้างนอก build หรือจะไว้ข้างในก็ได้)
  String _nextStatus(String current) {
    if (current == 'available') return 'occupied';
    if (current == 'occupied') return 'unavailable';
    if (current == 'unavailable' || current == 'held') return 'available';
    return 'available'; // Default case
  }

  @override
  Widget build(BuildContext context) {
    // สร้าง Service ภายใน build method (คล้าย parking_box ที่ใช้ FirebaseAuth.instance)
    final FirebaseParkingService parkingService = FirebaseParkingService();

    // --- สี (ยังคง Hardcode หรือจะดึงจาก Theme ก็ได้) ---
    const availableColor = Colors.green;
    const occupiedColor = Colors.red;
    const unavailableColor = Colors.grey;
    const heldColor = Colors.orange; // เพิ่ม held เผื่อ Admin เห็น
    const defaultColor = Colors.black;
    const textColor = Colors.white;

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('parking_spots')
              .doc(docId)
              .snapshots(),
      builder: (context, snapshot) {
        // --- ส่วนจัดการ Loading/Error ---
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            // แสดง Placeholder ขณะรอข้อมูลครั้งแรก
            width: direction == Axis.vertical ? 30 : 45,
            height: direction == Axis.vertical ? 45 : 30,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
          );
        }
        if (snapshot.hasError) {
          return Tooltip(
            // แสดง Tooltip บอก Error
            message: 'Error: ${snapshot.error}',
            child: Container(
              width: direction == Axis.vertical ? 30 : 45,
              height: direction == Axis.vertical ? 45 : 30,
              decoration: BoxDecoration(color: Colors.black /*...*/),
              alignment: Alignment.center,
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 18,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return Container(
            /* Placeholder ว่างเปล่า */
          ); // กรณี Document ไม่มีข้อมูล
        }

        // --- ส่วนแสดงผลหลัก ---
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = (data['status'] ?? 'unknown') as String;

        Color color;
        switch (status) {
          case 'available':
            color = availableColor;
            break;
          case 'occupied':
            color = occupiedColor;
            break;
          case 'unavailable':
            color = unavailableColor;
            break;
          case 'held':
            color = heldColor;
            break; // เพิ่ม held
          default:
            color = defaultColor;
        }

        return GestureDetector(
          onTap: () async {
            try {
              final nextStatus = _nextStatus(status);
              final Map<String, dynamic> updateData = {'status': nextStatus};

              if (nextStatus == 'occupied') {
                updateData['start_time'] = Timestamp.now();
              } else {
                updateData['start_time'] = null;
              }
              // ใช้ parkingService ที่สร้างใน build method
              await parkingService.updateParkingStatus(docId, updateData);
            } catch (e) {
              if (ScaffoldMessenger.maybeOf(context) != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('เปลี่ยนสถานะไม่สำเร็จ: $e')),
                );
              } else {
                debugPrint('Error updating status for $docId: $e');
              }
            }
          },
          child: Container(
            width: direction == Axis.vertical ? 30 : 45,
            height: direction == Axis.vertical ? 45 : 30,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              child: Text(
                '$id',
                style: const TextStyle(color: textColor, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}
