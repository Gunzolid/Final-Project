// lib/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mtproject/services/firebase_service.dart';

class EditProfilePage extends StatefulWidget {
  final String currentName;
  // ลบ currentEmail ออก
  // final String currentEmail;

  const EditProfilePage({
    super.key,
    required this.currentName,
    // ลบ required this.currentEmail ออก
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  // ลบ _emailController ออก
  // late TextEditingController _emailController;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    // ลบการกำหนดค่า _emailController ออก
  }

  @override
  void dispose() {
    _nameController.dispose();
    // ลบการ dispose _emailController ออก
    super.dispose();
  }

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
      // --- อัปเดตชื่อใน Firestore (ถ้ามีการเปลี่ยนแปลง) ---
      if (newName != widget.currentName) {
        // ตรวจสอบว่าฟังก์ชัน updateUserProfile รับแค่ uid กับ name
        await _firebaseService.updateUserProfile(user.uid, newName);
        profileUpdated = true;
        debugPrint("Name updated in Firestore.");
      }

      if (mounted) {
        if (profileUpdated) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('บันทึกชื่อสำเร็จ')));
          Navigator.pop(context, true); // ส่ง true กลับไปบอกว่ามีการเปลี่ยนแปลง
        } else {
          Navigator.pop(context, false); // ไม่มีการเปลี่ยนแปลง
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
      appBar: AppBar(
        title: const Text('แก้ไขชื่อโปรไฟล์'), // เปลี่ยน Title
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
              // ลบ TextFormField ของ Email ออก
              const SizedBox(height: 32),
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
