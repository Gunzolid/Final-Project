// lib/pages/admin_parking_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mtproject/models/admin_parking_map_layout.dart';
import 'package:mtproject/services/firebase_parking_service.dart';
import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/ui/adaptive_scaffold.dart';

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
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;
  bool _checkingAccess = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  Future<void> _verifyAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _redirectHome();
      return;
    }
    // ดักไว้สองชั้น: ถ้าไม่ได้เป็น Admin จะถูกเตะกลับไปหน้า Home ทันที
    final isAdmin = await _firebaseService.isAdmin(user.uid);
    if (!mounted) return;
    if (!isAdmin) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
      });
      _redirectHome();
    } else {
      setState(() {
        _hasAccess = true;
        _checkingAccess = false;
      });
    }
  }

  void _redirectHome() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    });
  }

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

  Widget _buildMapView() {
    return Column(
      children: [
        const Expanded(child: AdminParkingMapLayout()),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.event_available),
                label: const Text('ว่างทั้งหมด'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                ),
                onPressed: _isLoading ? null : () => _setAllStatus('available'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel_presentation_rounded),
                label: const Text('ปิดทั้งหมด'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                ),
                onPressed:
                    _isLoading ? null : () => _setAllStatus('unavailable'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('parking_spots').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('ไม่มีข้อมูลช่องจอด'));
        }
        final docs = snapshot.data!.docs;
        final items =
            docs
                .where(
                  (doc) =>
                      (doc.data()['status'] as String?)?.toLowerCase() ==
                      'occupied',
                )
                .map((doc) {
                  final data = doc.data();
                  final start = data['start_time'] as Timestamp?;
                  final startedAt = start?.toDate();
                  final duration =
                      startedAt != null
                          ? DateTime.now().difference(startedAt).inMinutes
                          : 0;
                  return {
                    'id': data['id'] ?? doc.id,
                    'since': startedAt,
                    'minutes': duration,
                  };
                })
                .toList()
              ..sort(
                (a, b) => (b['minutes'] as int).compareTo(a['minutes'] as int),
              );

        if (items.isEmpty) {
          return const Center(child: Text('ยังไม่มีรถจอดอยู่ในขณะนี้'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = items[index];
            final since = item['since'] as DateTime?;
            final minutes = item['minutes'] as int;
            final hours = (minutes / 60).toStringAsFixed(1);
            final sinceText =
                since != null
                    ? '${since.day.toString().padLeft(2, '0')}/'
                        '${since.month.toString().padLeft(2, '0')} '
                        '${since.hour.toString().padLeft(2, '0')}:${since.minute.toString().padLeft(2, '0')}'
                    : 'ไม่ทราบเวลาเริ่ม';
            return ListTile(
              leading: CircleAvatar(child: Text('${item['id']}')),
              title: Text('ช่อง ${item['id']}'),
              subtitle: Text('จอดมาแล้ว $hours ชั่วโมง (ตั้งแต่ $sinceText)'),
            );
          },
          separatorBuilder: (_, __) => const Divider(),
          itemCount: items.length,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasAccess) {
      return const Scaffold(
        body: Center(child: Text('ไม่มีสิทธิ์เข้าถึงหน้านี้')),
      );
    }

    return AdaptiveScaffold(
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
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildMapView(), _buildDashboard()],
      ),
      currentIndex: _selectedIndex,
      destinations: const [
        AdaptiveNavigationItem(icon: Icons.map, label: 'ผังที่จอด'),
        AdaptiveNavigationItem(icon: Icons.analytics, label: 'สรุปการใช้งาน'),
      ],
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
    );
  }
}
