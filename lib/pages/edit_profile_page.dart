// lib/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mtproject/services/firebase_service.dart';

// =================================================================================
// หน้าแก้ไขโปรไฟล์ (EDIT PROFILE PAGE)
// =================================================================================
// อนุญาตให้ผู้ใช้แก้ไขชื่อ (Display Name) ได้ แต่ไม่ให้แก้ Email

class EditProfilePage extends StatefulWidget {
  final String currentName;

  const EditProfilePage({super.key, required this.currentName});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // บันทึกข้อมูล
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final newName = _nameController.text.trim();
    bool profileUpdated = false;

    try {
      // ตรวจสอบว่าชื่อเปลี่ยนไปหรือไม่
      if (newName != widget.currentName) {
        // อัปเดตใน Firestore
        await _firebaseService.updateUserProfile(user.uid, newName);
        // อัปเดตใน Auth Profile
        await user.updateDisplayName(newName);
        profileUpdated = true;
        debugPrint("Name updated in Firestore.");
      }

      if (mounted) {
        if (profileUpdated) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('บันทึกชื่อสำเร็จ')));
          Navigator.pop(
            context,
            true,
          ); // ส่ง true เพื่อบอกหน้าแม่ว่ามีการเปลี่ยนแปลง
        } else {
          Navigator.pop(context, false); // ส่ง false (ไม่มีอะไรเปลี่ยน)
        }
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขชื่อโปรไฟล์')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ช่องกรอกชื่อ
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'ชื่อ'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // ปุ่มบันทึก
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('บันทึก'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
