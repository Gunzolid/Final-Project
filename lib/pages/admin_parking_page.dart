// lib/pages/admin_parking_page.dart
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mtproject/models/admin_parking_map_layout.dart';

import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/ui/adaptive_scaffold.dart';

import 'package:mtproject/pages/admin/admin_dashboard_page.dart';
import 'package:mtproject/pages/admin/admin_spot_list_page.dart';

// =================================================================================
// หน้า Admin Console (ทางเลือก)
// =================================================================================
// หน้านี้คล้ายกับ AdminRootPage ใช้สำหรับเข้าถึงฟังก์ชันของผู้ดูแลระบบ
// ตรวจสอบสิทธิ์ก่อนเข้าใช้งาน และรวบรวมเมนูต่างๆ ไว้ในที่เดียว

class AdminParkingPage extends StatefulWidget {
  const AdminParkingPage({super.key});

  @override
  State<AdminParkingPage> createState() => _AdminParkingPageState();
}

class _AdminParkingPageState extends State<AdminParkingPage> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;
  bool _checkingAccess = true; // กำลังตรวจสอบสิทธิ์
  bool _hasAccess = false; // มีสิทธิ์หรือไม่

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  // ตรวจสอบว่าเป็น Admin หรือไม่
  Future<void> _verifyAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _redirectHome();
      return;
    }
    final isAdmin = await _firebaseService.isAdmin(user.uid);
    if (!mounted) return;
    if (!isAdmin) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
      });
      _redirectHome(); // ถ้าไม่ใช่ Admin ให้ดีดกลับหน้า Home
    } else {
      setState(() {
        _hasAccess = true;
        _checkingAccess = false;
      });
    }
  }

  // ดีดกลับหน้า Home
  void _redirectHome() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    });
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

    // หน้าเมนูย่อยของ Admin
    final List<Widget> pages = [
      const AdminDashboardPage(), // Dashboard สรุปผล
      const AdminSpotListPage(), // จัดการสถานะรายช่อง
      const AdminParkingMapLayout(), // ดูแผนที่ในมุมมอง Admin
    ];

    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text("Admin Console"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            },
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      currentIndex: _selectedIndex,
      destinations: const [
        AdaptiveNavigationItem(icon: Icons.dashboard, label: 'Dashboard'),
        AdaptiveNavigationItem(icon: Icons.list_alt, label: 'Manage Spots'),
        AdaptiveNavigationItem(icon: Icons.map, label: 'Map View'),
      ],
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
    );
  }
}
