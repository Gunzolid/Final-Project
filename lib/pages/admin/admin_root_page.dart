// lib/pages/admin/admin_root_page.dart
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mtproject/models/parking_map_layout.dart';

import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/ui/adaptive_scaffold.dart';
import 'package:mtproject/pages/admin/admin_dashboard_page.dart';
import 'package:mtproject/pages/admin/admin_spot_list_page.dart';
import 'package:mtproject/pages/admin/admin_instruction_page.dart';
import 'package:mtproject/pages/profile_page.dart';

// =================================================================================
// หน้าหลักผู้ดูแลระบบ (ADMIN ROOT PAGE)
// =================================================================================
// เป็นจุดศูนย์รวมของ Admin Console โดยใช้ AdaptiveScaffold เพื่อจัดการ Navigation
// มีการตรวจสอบสิทธิ์ความปลอดภัยก่อนเข้าใช้งาน

class AdminRootPage extends StatefulWidget {
  const AdminRootPage({super.key});

  @override
  State<AdminRootPage> createState() => _AdminRootPageState();
}

class _AdminRootPageState extends State<AdminRootPage> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;
  bool _checkingAccess = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  // ตรวจสอบสิทธิ์ว่าเป็น Admin จริงหรือไม่
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
      _redirectHome();
    } else {
      setState(() {
        _hasAccess = true;
        _checkingAccess = false;
      });
    }
  }

  // ส่งกลับหน้า Home หากไม่มีสิทธิ์
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

    // รวมหน้าย่อยทั้งหมดของ Admin
    final List<Widget> pages = [
      const AdminDashboardPage(), // หน้าสรุปผลรวม
      const AdminSpotListPage(), // หน้าจัดการสถานะรายช่อง
      const ParkingMapLayout(isAdmin: true), // หน้าแผนที่ (โหมด Admin)
      const AdminInstructionPage(), // คู่มือ Admin
      const ProfilePage(), // โปรไฟล์ส่วนตัว
    ];

    return AdaptiveScaffold(
      appBar: AppBar(title: const Text("Admin Console")),
      body: IndexedStack(index: _selectedIndex, children: pages),
      currentIndex: _selectedIndex,
      destinations: const [
        AdaptiveNavigationItem(icon: Icons.dashboard, label: 'Dashboard'),
        AdaptiveNavigationItem(icon: Icons.list_alt, label: 'Manage Spots'),
        AdaptiveNavigationItem(icon: Icons.map, label: 'Map View'),
        AdaptiveNavigationItem(icon: Icons.help_outline, label: 'Manual'),
        AdaptiveNavigationItem(icon: Icons.person, label: 'Profile'),
      ],
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
    );
  }
}
