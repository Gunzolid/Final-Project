// lib/ui/recommend_dialog.dart
import 'package:flutter/material.dart';
import 'package:mtproject/services/directions_service.dart';

/// ฟังก์ชันแสดง Popup แนะนำช่องจอดที่หาเจอ
/// พร้อมถามผู้ใช้ว่าต้องการเปิด Google Maps นำทางไปหรือไม่
Future<void> showRecommendDialog(
  BuildContext context, {
  required List<int> recommendedIds, // รายการ ID ของช่องจอดที่แนะนำ
  String? helperMessage, // ข้อความเพิ่มเติม (ถ้ามี)
}) async {
  // กรณีไม่พบช่องจอด
  if (recommendedIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ไม่พบช่องที่เหมาะสมในตอนนี้')),
    );
    return;
  }

  // แสดง Dialog และรอผลลัพธ์ (กดตกลง หรือ ยกเลิก)
  final bool? go = await showDialog<bool>(
    context: context,
    barrierDismissible: true, // แตะพื้นที่ว่างด้านนอกเพื่อปิดได้
    builder:
        (dialogCtx) => AlertDialog(
          title: const Text('พบช่องจอดที่แนะนำ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ช่องที่แนะนำ:'),
              const SizedBox(height: 8),
              // แสดงรายการช่องจอดเป็น Chip (ป้ายกำกับ)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    recommendedIds
                        .map(
                          (id) => Chip(
                            label: Text('ช่อง $id'),
                            avatar: const Icon(Icons.local_parking, size: 18),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              // ข้อความถามเรื่องนำทาง
              const Text(
                'ต้องการส่งตำแหน่งปัจจุบันไปยัง Google Maps '
                'เพื่อคำนวณเส้นทางไปยัง ม.อ.ภูเก็ต (ตึก 6) หรือไม่?',
              ),
              if (helperMessage != null) ...[
                const SizedBox(height: 12),
                Text(helperMessage),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false), // ตอบ No
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.navigation),
              label: const Text('ตกลง'),
              onPressed: () => Navigator.of(dialogCtx).pop(true), // ตอบ Yes
            ),
          ],
        ),
  );

  // ถ้าผู้ใช้กด "ตกลง"
  if (go == true) {
    try {
      await openGoogleMapsToPSUPK(); // สั่งเปิด Google Maps
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เปิดแผนที่ไม่ได้: $e')));
      }
    }
  }
}
