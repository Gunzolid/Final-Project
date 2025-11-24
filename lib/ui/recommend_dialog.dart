// lib/ui/recommend_dialog.dart
import 'package:flutter/material.dart';
import 'package:mtproject/services/directions_service.dart';

/// โชว์ popup แนะนำช่อง + ถามเปิด Google Maps ไปตึก 6
Future<void> showRecommendDialog(
  BuildContext context, {
  required List<int> recommendedIds,
  String? helperMessage,
}) async {
  if (recommendedIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ไม่พบช่องที่เหมาะสมในตอนนี้')),
    );
    return;
  }

  final bool? go = await showDialog<bool>(
    context: context,
    barrierDismissible: true, // แตะนอกกล่องเพื่อปิดได้
    builder:
        (dialogCtx) => AlertDialog(
          title: const Text('พบช่องจอดที่แนะนำ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ช่องที่แนะนำ:'),
              const SizedBox(height: 8),
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
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.navigation),
              label: const Text('ตกลง'),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
            ),
          ],
        ),
  );

  if (go == true) {
    try {
      await openGoogleMapsToPSUPK();
    } catch (e) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text('เปิดแผนที่ไม่ได้: $e')));
    }
  }
}
