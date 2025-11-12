// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mtproject/pages/edit_profile_page.dart';
import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/services/theme_manager.dart';
import 'package:mtproject/pages/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    if (_currentUser != null) {
      // VVV 1. แก้ไขชื่อฟังก์ชันตรงนี้ VVV
      final data = await _firebaseService.getUserProfile();
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    // ... (โค้ดส่วนนี้เหมือนเดิม) ...
    final user = _currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ยืนยันการลบบัญชี'),
            content: const Text(
              'คุณแน่ใจหรือไม่ว่าต้องการลบบัญชีนี้? การดำเนินการนี้ไม่สามารถย้อนกลับได้ และข้อมูลทั้งหมดของคุณจะถูกลบ',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('ลบบัญชี'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firebaseService.deleteUserData(user.uid);
        await user.delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ลบบัญชีสำเร็จ')));
          // Navigator.pushAndRemoveUntil(
          //   context,
          //   MaterialPageRoute(builder: (_) => const LoginPage()),
          // ใช้ pushNamedAndRemoveUntil เพื่อล้างสแต็คและกลับไปที่ Home หลังลบบัญชี
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } on FirebaseAuthException catch (e) {
        print("Error deleting account: ${e.code} - ${e.message}");
        String message = 'เกิดข้อผิดพลาดในการลบบัญชี';
        if (e.code == 'requires-recent-login') {
          message =
              'การดำเนินการนี้ต้องมีการล็อกอินใหม่ กรุณาออกจากระบบแล้วล็อกอินอีกครั้งเพื่อลบบัญชี';
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        print("Error deleting account (Firestore or other): $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : user == null
              ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้'))
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  CircleAvatar(
                    radius: 50,
                    child: const Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userData?['name'] ?? 'N/A',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? 'N/A',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('แก้ไขชื่อโปรไฟล์'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => EditProfilePage(
                                currentName: _userData?['name'] ?? '',
                              ),
                        ),
                      );
                      if (result == true && mounted) {
                        _loadUserData();
                      }
                    },
                  ),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (_, currentMode, __) {
                      bool isDarkMode = currentMode == ThemeMode.dark;
                      return SwitchListTile(
                        secondary: Icon(
                          isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        ),
                        title: const Text('โหมดกลางคืน'),
                        value: isDarkMode,
                        onChanged: (value) {
                          themeNotifier.value =
                              value ? ThemeMode.dark : ThemeMode.light;
                        },
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: Colors.red.shade400,
                    ),
                    title: Text(
                      'ลบบัญชี',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                    onTap: _deleteAccount,
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.orange.shade700),
                    title: Text(
                      'ออกจากระบบ',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                    onTap: () async {
                      // VVV 2. แก้ไขการเรียกใช้ตรงนี้ VVV
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        // Navigator.pushAndRemoveUntil(
                        //   context,
                        //   MaterialPageRoute(builder: (_) => const LoginPage()),
                        // ใช้ pushNamedAndRemoveUntil เพื่อล้างสแต็คและให้หน้า Home เป็น root
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/home', (route) => false);
                      }
                    },
                  ),
                ],
              ),
    );
  }
}
