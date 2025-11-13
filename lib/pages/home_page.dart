// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/models/parking_map_layout.dart';
import 'package:mtproject/pages/login_page.dart';
import 'package:mtproject/pages/profile_page.dart';
import 'package:mtproject/services/firebase_parking_service.dart';
import 'package:mtproject/pages/searching_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // State for Home Page Content
  bool _isSearching = false;
  int? _recommendedSpotLocal;
  StreamSubscription? _recSub;

  User? _currentUser;
  bool _isLoadingUser = true;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _recSub?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
        if (user != null) {
          _checkExistingHold();
        } else {
          setState(() {
            _recommendedSpotLocal = null;
          });
          _recSub?.cancel();
        }
      }
    });
  }

  // --- (ฟังก์ชัน _checkExistingHold, _startSearching, _watchSpot, _cancelCurrentHold ทั้งหมดเหมือนเดิม) ---
  Future<void> _checkExistingHold() async {
    final user = _currentUser;
    if (user == null) return;
    final query =
        await FirebaseFirestore.instance
            .collection('parking_spots')
            .where('hold_by', isEqualTo: user.uid)
            .limit(1)
            .get();
    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final spotId = int.tryParse(doc.id);
      if (spotId != null && mounted) {
        setState(() {
          _recommendedSpotLocal = spotId;
        });
        _watchSpot(spotId);
      }
    }
  }

  Future<void> _startSearching() async {
    if (_currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }
    if (_isSearching) return;
    setState(() => _isSearching = true);
    try {
      final resultSpotId = await Navigator.push<int?>(
        context,
        MaterialPageRoute(builder: (_) => const SearchingPage()),
      );
      if (resultSpotId != null) {
        setState(() => _recommendedSpotLocal = resultSpotId);
        _watchSpot(resultSpotId);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _watchSpot(int spotId) {
    _recSub?.cancel();
    _recSub = FirebaseParkingService().watchRecommendation(spotId).listen((
      recommendation,
    ) {
      if (!recommendation.isActive) {
        final msg = recommendation.reason ?? 'การจองสิ้นสุดลงแล้ว';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
          setState(() => _recommendedSpotLocal = null);
        }
        _recSub?.cancel();
      }
    });
  }

  Future<void> _cancelCurrentHold() async {
    if (_currentUser == null || _recommendedSpotLocal == null) return;
    final spotToCancel = _recommendedSpotLocal!;
    try {
      await FirebaseParkingService().cancelHold(spotToCancel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ยกเลิกการจองช่อง $spotToCancel สำเร็จ')),
        );
        setState(() {
          _recommendedSpotLocal = null;
        });
        _recSub?.cancel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการยกเลิก: $e')),
        );
      }
    }
  }
  // --- สิ้นสุดฟังก์ชันที่คัดลอกมา ---

  // =================================================================
  //  VVV      จุดแก้ไขหลัก: _buildHomePageContent      VVV
  // =================================================================
  Widget _buildHomePageContent() {
    final bool isLoggedIn = _currentUser != null;
    final bool hasRecommendation = _recommendedSpotLocal != null;
    final bool canSearch = isLoggedIn && !_isSearching && !hasRecommendation;

    // 1. เปลี่ยนจาก Column เป็น Stack
    return Stack(
      children: [
        // 2. แผนที่จะอยู่เป็นพื้นหลังสุด
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(16.0), // ย้าย Padding มาไว้ข้างใน
            child: ParkingMapLayout(recommendedSpot: _recommendedSpotLocal),
          ),
        ),

        // 3. UI ทั้งหมดที่อยู่ด้านล่าง จะ "ลอย" ทับแผนที่
        Positioned(
          bottom: 16, // ปรับระยะห่างจากขอบล่าง
          left: 16,
          right: 16,
          child: Column(
            // ใช้ Column เพื่อจัดเรียง UI ที่ลอยอยู่
            children: [
              // --- 4. ย้าย "จำนวนพื้นที่ว่าง" มาไว้ที่นี่ ---
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('parking_spots')
                        .where('status', isEqualTo: 'available')
                        .snapshots(),
                builder: (context, snapshot) {
                  // ใส่พื้นหลังให้ข้อความเพื่อให้อ่านง่าย
                  final brightness = Theme.of(context).brightness;
                  final bgColor =
                      brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.7)
                          : Colors.white.withOpacity(0.9);
                  final textColor =
                      brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black;

                  Widget content;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    content = Text(
                      'กำลังโหลด...',
                      style: TextStyle(color: textColor, fontSize: 14),
                    );
                  } else if (snapshot.hasError) {
                    content = Text(
                      'โหลดข้อมูลไม่ได้',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 14,
                      ),
                    );
                  } else {
                    final available = snapshot.data?.docs.length ?? 0;
                    content = Text(
                      "พื้นที่ว่าง: $available/52",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }

                  return Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(8),
                    color: bgColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: content,
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // --- 5. ย้าย "ข้อความแนะนำ/ปุ่มยกเลิก" มาไว้ที่นี่ ---
              if (isLoggedIn && hasRecommendation)
                Material(
                  // เพิ่มพื้นหลัง
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.7)
                          : Colors.white.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "แนะนำช่อง: $_recommendedSpotLocal",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text(
                            'ยกเลิก',
                            style: TextStyle(color: Colors.red),
                          ),
                          onPressed: _cancelCurrentHold,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16), // ปรับ Sizedbox
              // --- 6. ย้าย "ปุ่มค้นหา" มาไว้ที่นี่ ---
              if (_isLoadingUser)
                const CircularProgressIndicator()
              else if (isLoggedIn)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canSearch ? _startSearching : null,
                    child: Text(
                      _isSearching
                          ? 'กำลังค้นหา...'
                          : (hasRecommendation
                              ? 'คุณมีช่องจอดที่แนะนำแล้ว'
                              : 'ค้นหาที่จอดรถ'),
                    ),
                  ),
                ),
              // (ส่วน else ที่แสดงปุ่ม Login ด้านล่าง ถูกลบออกไปแล้ว ถูกต้อง)
            ],
          ),
        ),
      ],
    );
  }
  // =================================================================
  //  ^^^      สิ้นสุดการแก้ไข _buildHomePageContent      ^^^
  // =================================================================

  @override
  Widget build(BuildContext context) {
    // --- สร้าง List ของหน้าต่างๆ (เหมือนเดิม) ---
    final List<Widget> pages = [
      _buildHomePageContent(), // index 0: หน้า Home
      _currentUser != null
          ? const ProfilePage()
          : const LoginPage(), // index 1: หน้า Profile หรือ Login
    ];

    return Scaffold(
      appBar: AppBar(
        // ป้องกันไม่ให้มีปุ่มย้อนกลับหากมีการ push หน้านี้ผิดพลาด
        automaticallyImplyLeading: false,
        title: const Text('Smart Parking'),
      ),
      // --- ใช้ IndexedStack (เหมือนเดิม) ---
      body: IndexedStack(index: _currentIndex, children: pages),
      // --- BottomNavigationBar (เหมือนเดิม) ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1 && _currentUser == null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าหลัก'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
        ],
      ),
    );
  }
}
