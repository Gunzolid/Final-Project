// lib/pages/admin/admin_instruction_page.dart
import 'package:flutter/material.dart';

// =================================================================================
// หน้าคู่มือผู้ดูแลระบบ (ADMIN INSTRUCTION PAGE)
// =================================================================================
// แนะนำการใช้งานฟีเจอร์ต่างๆ ของฝั่ง Admin

class AdminInstructionPage extends StatelessWidget {
  const AdminInstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คู่มือผู้ดูแลระบบ')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStep(
            context,
            '1',
            'Dashboard Overview',
            'หน้า Dashboard แสดงภาพรวมสถานะของช่องจอดทั้งหมด (ว่าง, มีรถจอด, จอง, ปิดบริการ) และประวัติการใช้งานล่าสุด',
            Icons.dashboard,
          ),
          _buildStep(
            context,
            '2',
            'จัดการช่องจอด',
            'ในหน้า Manage Spots คุณสามารถเปลี่ยนสถานะของแต่ละช่องจอดได้ด้วยตนเอง เช่น ตั้งเป็น "ว่าง" หรือ "ปิดบริการ"',
            Icons.edit_location_alt,
          ),
          _buildStep(
            context,
            '3',
            'การจัดการแบบกลุ่ม',
            'ปุ่ม "Set All Available" จะรีเซ็ตทุกช่องให้ว่าง (ใช้ตอนเปิดลานจอด) และ "Set All Unavailable" จะปิดทุกช่อง (ใช้ตอนปิดลานจอด)',
            Icons.layers,
          ),
          _buildStep(
            context,
            '4',
            'Map View',
            'หน้า Map View แสดงผังลานจอดรถในมุมมองจริง ช่วยให้เห็นภาพรวมตำแหน่งของรถแต่ละคัน',
            Icons.map,
          ),
        ],
      ),
    );
  }

  // สร้างการ์ดแสดงขั้นตอนการใช้งาน
  Widget _buildStep(
    BuildContext context,
    String number,
    String title,
    String description,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
