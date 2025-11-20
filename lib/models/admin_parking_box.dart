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

  @override
  Widget build(BuildContext context) {
    // สร้าง Service ภายใน build method (คล้าย parking_box ที่ใช้ FirebaseAuth.instance)
    final FirebaseParkingService parkingService = FirebaseParkingService();

    // --- สี (ยังคง Hardcode หรือจะดึงจาก Theme ก็ได้) ---
    const textColor = Colors.white;
    const statuses = ['available', 'occupied', 'unavailable', 'held'];

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
        final status = (data['status'] ?? 'unknown').toString().toLowerCase();

        final note = data['note'] as String?;
        final tooltipText =
            note != null && note.isNotEmpty
                ? 'สถานะ: $status\nหมายเหตุ: $note'
                : 'สถานะ: $status';

        return Tooltip(
          message: tooltipText,
          child: SizedBox(
            width: direction == Axis.vertical ? 30 : 45,
            height: direction == Axis.vertical ? 45 : 30,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: status,
                isExpanded: true,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  size: 12,
                  color: Colors.white,
                ),
                items:
                    statuses
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.toUpperCase()),
                          ),
                        )
                        .toList(),
                selectedItemBuilder: (context) {
                  return statuses
                      .map(
                        (item) => _buildBox(
                          _statusColor(item),
                          textColor: textColor,
                          hasNote:
                              item == status && note != null && note.isNotEmpty,
                        ),
                      )
                      .toList();
                },
                onChanged: (value) async {
                  if (value == null || value == status) return;
                  try {
                    final Map<String, dynamic> updateData = {'status': value};
                    if (value == 'occupied') {
                      updateData['start_time'] = Timestamp.now();
                    } else if (value == 'available') {
                      updateData['start_time'] = null;
                    }
                    if (value == 'unavailable') {
                      final noteText = await _promptNote(context, note);
                      if (noteText == null) {
                        return;
                      }
                      updateData['note'] = noteText;
                      updateData['start_time'] = null;
                    } else {
                      updateData['note'] = null;
                    }
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
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.red;
      case 'unavailable':
        return Colors.grey;
      case 'held':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  /// Prompts the admin to provide a reason whenever a spot becomes unavailable.
  /// Returning `null` cancels the change so we never store an empty note.
  Future<String?> _promptNote(BuildContext context, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('สาเหตุการปิดใช้งาน'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'เช่น ซ่อมบำรุง'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('บันทึก'),
              ),
            ],
          ),
    );
    return result == null || result.isEmpty ? null : result;
  }

  Widget _buildBox(Color color, {Color? textColor, bool hasNote = false}) {
    final base = Container(
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
          style: TextStyle(color: textColor ?? Colors.white, fontSize: 12),
        ),
      ),
    );

    if (!hasNote) return base;

    return Stack(
      children: [
        base,
        Positioned(
          top: 2,
          right: 2,
          child: Icon(Icons.sticky_note_2, size: 12, color: Colors.white),
        ),
      ],
    );
  }
}
