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
    final FirebaseParkingService parkingService = FirebaseParkingService();

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('parking_spots')
              .doc(docId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildPlaceholder(Colors.grey.shade300);
        }
        if (snapshot.hasError) {
          return Tooltip(
            message: 'Error: ${snapshot.error}',
            child: _buildPlaceholder(Colors.black, icon: Icons.error_outline),
          );
        }
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return _buildPlaceholder(Colors.grey);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = (data['status'] ?? 'unknown').toString().toLowerCase();
        final note = data['note'] as String?;
        final tooltipText =
            note != null && note.isNotEmpty
                ? 'สถานะ: $status\nหมายเหตุ: $note'
                : 'สถานะ: $status';

        return Tooltip(
          message: tooltipText,
          child: InkWell(
            onTap: () => _showStatusDialog(context, status, note, parkingService),
            child: _buildBox(
              _statusColor(status),
              textColor: Colors.white,
              hasNote: note != null && note.isNotEmpty,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(Color color, {IconData? icon}) {
    return Container(
      width: direction == Axis.vertical ? 30 : 45,
      height: direction == Axis.vertical ? 45 : 30,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child:
          icon != null
              ? Icon(icon, color: Colors.red, size: 18)
              : const SizedBox(),
    );
  }

  Future<void> _showStatusDialog(
    BuildContext context,
    String currentStatus,
    String? currentNote,
    FirebaseParkingService parkingService,
  ) async {
    String selectedStatus = currentStatus;
    final noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('จัดการช่องจอด $id'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'สถานะ'),
                    items:
                        ['available', 'occupied', 'unavailable', 'held']
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.toUpperCase()),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => selectedStatus = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedStatus == 'unavailable')
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'หมายเหตุ (สาเหตุ)',
                        hintText: 'เช่น ซ่อมบำรุง',
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final updates = <String, dynamic>{
                        'status': selectedStatus,
                      };
                      if (selectedStatus == 'unavailable') {
                        updates['note'] = noteController.text.trim();
                        updates['start_time'] = null;
                      } else if (selectedStatus == 'available') {
                        updates['start_time'] = null;
                        updates['note'] = null;
                      } else if (selectedStatus == 'occupied') {
                        updates['start_time'] = Timestamp.now();
                        updates['note'] = null;
                      } else {
                        updates['note'] = null;
                      }

                      await parkingService.updateParkingStatus(docId, updates);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
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

  Widget _buildBox(Color color, {Color? textColor, bool hasNote = false}) {
    final base = Container(
      width: direction == Axis.vertical ? 30 : 45,
      height: direction == Axis.vertical ? 45 : 30,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Text(
          '$id',
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (!hasNote) return base;

    return Stack(
      children: [
        base,
        const Positioned(
          top: 2,
          right: 2,
          child: Icon(Icons.sticky_note_2, size: 12, color: Colors.white),
        ),
      ],
    );
  }
}
