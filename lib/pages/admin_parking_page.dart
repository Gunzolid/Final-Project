// lib/pages/admin_parking_page.dart
import 'package:flutter/material.dart';
import 'package:mtproject/models/admin_parking_map_layout.dart';
// 1. Import Service
import 'package:mtproject/services/firebase_parking_service.dart';
// Import หน้า Login เผื่อใช้ตอน Logout
import 'package:mtproject/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 2. เปลี่ยนเป็น StatefulWidget
class AdminParkingPage extends StatefulWidget {
  const AdminParkingPage({super.key});

  @override
  State<AdminParkingPage> createState() => _AdminParkingPageState();
}

class _AdminParkingPageState extends State<AdminParkingPage> {
  // 3. เพิ่ม State สำหรับ Loading
  bool _isLoading = false;
  final FirebaseParkingService _parkingService =
      FirebaseParkingService(); // สร้าง instance ไว้ใช้

  // 4. สร้างฟังก์ชันสำหรับจัดการการกดปุ่ม
  Future<void> _setAllStatus(String status) async {
    // แสดง Dialog ยืนยันก่อน
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('ยืนยันการเปลี่ยนแปลง'),
            content: Text(
              'คุณแน่ใจหรือไม่ว่าต้องการเปลี่ยนสถานะทุกช่องเป็น "$status"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor:
                      status == 'available' ? Colors.green : Colors.orange,
                ),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true); // เริ่ม Loading
      try {
        await _parkingService.updateAllSpotsStatus(status);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เปลี่ยนสถานะทุกช่องเป็น "$status" สำเร็จ')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false); // สิ้นสุด Loading
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin - จัดการที่จอดรถ"),
        actions: [
          // เพิ่มปุ่ม Logout (Optional)
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                // Navigator.pushAndRemoveUntil(
                //   context,
                //   MaterialPageRoute(builder: (_) => const LoginPage()),
                // ใช้ pushNamedAndRemoveUntil เพื่อล้างสแต็คและให้หน้า Home เป็น root หลังออกจากระบบ
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Column(
        // ใช้ Column ครอบ
        children: [
          // แผนผัง (เหมือนเดิม)
          const Expanded(child: AdminParkingMapLayout()),

          // แสดง Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),

          // 5. เพิ่มปุ่มควบคุมทั้งหมด
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.event_available),
                  label: const Text('ว่างทั้งหมด'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                  ),
                  // ปิดปุ่มขณะ Loading
                  onPressed:
                      _isLoading ? null : () => _setAllStatus('available'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel_presentation_rounded),
                  label: const Text('ปิดทั้งหมด'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                  ),
                  // ปิดปุ่มขณะ Loading
                  onPressed:
                      _isLoading ? null : () => _setAllStatus('unavailable'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
