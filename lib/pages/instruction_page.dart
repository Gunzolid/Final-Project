import 'package:flutter/material.dart';

class InstructionPage extends StatelessWidget {
  const InstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คำแนะนำการใช้งาน')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatusColorsStep(context, '1'),
          _buildStep(
            context,
            '2',
            'ค้นหาที่จอดรถ',
            'ต้องทำการเข้าสู่ระบบก่อนจึงจะสามารถกดปุ่ม "ค้นหาที่จอดรถ" ในหน้าหลักได้ ระบบจะแนะนำช่องจอดที่ว่างและใกล้ที่สุดให้คุณ',
            Icons.search,
          ),
          _buildStep(
            context,
            '3',
            'นำทางไปยังช่องจอด',
            'เมื่อได้ช่องจอดแล้ว คุณสามารถกดปุ่มเพื่อเปิด Google Maps นำทางไปยังอาคารจอดรถได้ทันที',
            Icons.navigation,
          ),
          _buildStep(
            context,
            '4',
            'เข้าจอด',
            'เมื่อนำรถเข้าจอดในช่องที่แนะนำ ระบบจะตรวจจับรถและเปลี่ยนสถานะเป็น "ไม่ว่าง" โดยอัตโนมัติ',
            Icons.directions_car,
          ),
          _buildStep(
            context,
            '5',
            'ออกจอด',
            'เมื่อออกจอด ระบบจะตรวจจับรถและเปลี่ยนสถานะเป็น "ว่าง" โดยอัตโนมัติ',
            Icons.directions_car,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusColorsStep(BuildContext context, String number) {
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
                        Icons.color_lens,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ความหมายของสีช่องจอด',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildColorItem(
                    context,
                    Colors.green,
                    'สีเขียว',
                    'ว่าง (Available)',
                  ),
                  _buildColorItem(
                    context,
                    Colors.red,
                    'สีแดง',
                    'ไม่ว่าง (Occupied)',
                  ),
                  _buildColorItem(
                    context,
                    Colors.orange,
                    'สีส้ม',
                    'จอง (Held)',
                  ),
                  _buildColorItem(
                    context,
                    Colors.grey,
                    'สีเทา',
                    'ปิดบริการ (Unavailable)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorItem(
    BuildContext context,
    Color color,
    String label,
    String desc,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(desc)),
        ],
      ),
    );
  }

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
