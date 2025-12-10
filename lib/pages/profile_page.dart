// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mtproject/pages/edit_profile_page.dart';
import 'package:mtproject/pages/instruction_page.dart';
import 'package:mtproject/services/firebase_service.dart';
import 'package:mtproject/services/theme_manager.dart';

// =================================================================================
// หน้าโปรไฟล์ (PROFILE PAGE)
// =================================================================================
// แสดงข้อมูลผู้ใช้, เปลี่ยนรูปโปรไฟล์, แก้ไขชื่อ, เปลี่ยนธีม, และออกจากระบบ

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
  String? _profileEmail;

  // รายการรูปโปรไฟล์ (Avatar) ที่มีให้เลือก
  final List<IconData> _avatarIcons = [
    Icons.person,
    Icons.face,
    Icons.face_3,
    Icons.face_4,
    Icons.face_6,
    Icons.account_circle,
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
  }

  // โหลดข้อมูลผู้ใช้จาก Firestore
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    if (_currentUser != null) {
      final data = await _firebaseService.getUserProfile();
      if (mounted) {
        setState(() {
          _userData = data;
          _profileEmail =
              data?['email'] as String? ?? _currentUser?.email ?? '-';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // แสดง Dialog ให้เลือกรูปโปรไฟล์
  Future<void> _showAvatarSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('เลือกรูปโปรไฟล์'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: _avatarIcons.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => _updateAvatar(index), // เลือกแล้วอัปเดตเลย
                  borderRadius: BorderRadius.circular(50),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      _avatarIcons[index],
                      size: 30,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        );
      },
    );
  }

  // อัปเดต index ของรูปโปรไฟล์ใน Firestore
  Future<void> _updateAvatar(int index) async {
    Navigator.pop(context); // ปิด Dialog
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      await _firebaseService.updateUserData(_currentUser!.uid, {
        'avatarIndex': index,
      });
      await _loadUserData(); // โหลดข้อมูลใหม่เพื่อแสดงผล
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    // หา Icon ที่ใช้อยู่ปัจจุบัน
    final avatarIndex = _userData?['avatarIndex'] as int? ?? 0;
    final currentAvatar =
        (avatarIndex >= 0 && avatarIndex < _avatarIcons.length)
            ? _avatarIcons[avatarIndex]
            : _avatarIcons[0];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : user == null
              ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้'))
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // ส่วนแสดงรูปโปรไฟล์ + ปุ่มแก้ไข
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          child: Icon(currentAvatar, size: 50),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _showAvatarSelectionDialog,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ชื่อและอีเมล
                  Text(
                    _userData?['name'] ?? 'N/A',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profileEmail ?? user.email ?? 'N/A',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // เมนูต่างๆ
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('แก้ไขชื่อโปรไฟล์'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // เปิดหน้าแก้ไขชื่อ
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => EditProfilePage(
                                currentName: _userData?['name'] ?? '',
                              ),
                        ),
                      );
                      // ถ้าแก้ไขสำเร็จ (result == true) ให้โหลดข้อมูลใหม่
                      if (result == true && mounted) {
                        _loadUserData();
                      }
                    },
                  ),

                  // สวิตช์เปิด/ปิด Dark Mode
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, child) {
                      bool isDarkMode = currentMode == ThemeMode.dark;
                      return SwitchListTile(
                        secondary: Icon(
                          isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        ),
                        title: const Text('โหมดกลางคืน'),
                        value: isDarkMode,
                        onChanged: (value) {
                          ThemeManager.updateTheme(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      );
                    },
                  ),
                  const Divider(),

                  // ปุ่มคำแนะนำการใช้งาน
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('คำแนะนำการใช้งาน'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InstructionPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(),

                  // ปุ่ม Logout
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.orange.shade700),
                    title: Text(
                      'ออกจากระบบ',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      // กลับไปหน้า Home และเคลียร์ Stack
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/home', (route) => false);
                    },
                  ),
                ],
              ),
    );
  }
}
