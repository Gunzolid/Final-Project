// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/models/parking_map_layout.dart';
import 'package:mtproject/models/parking_layout_config.dart';
import 'package:mtproject/pages/login_page.dart';
import 'package:mtproject/pages/profile_page.dart';
import 'package:mtproject/services/firebase_parking_service.dart';
import 'package:mtproject/pages/searching_page.dart';
import 'package:mtproject/ui/adaptive_scaffold.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mtproject/pages/instruction_page.dart';

// =================================================================================
// หน้าหลัก (HOME PAGE)
// =================================================================================
// หน้าแรกของแอปพลิเคชัน แสดงแผนที่ลานจอดรถ สถานะช่องจอดแบบเรียลไทม์
// และจัดการฟังก์ชันหลักเช่น การค้นหาที่จอด (Searching) และการจอง (Holding)

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // Index ของเมนูนำทาง (0=Home, 1=Profile)

  // --- ตัวแปรสำหรับจัดการสถานะในหน้า Home ---
  bool _isSearching = false; // กำลังอยู่ในหน้าค้นหาหรือไม่
  int? _recommendedSpotLocal; // ID ช่องจอดที่ได้รับแนะนำ (ถ้ามี)
  StreamSubscription? _recSub; // Subscription สำหรับติดตามสถานะช่องแนะนำ
  bool _isRecommendationDialogVisible = false; // ป้องกัน dialog ซ้อนกัน

  User? _currentUser; // ผู้ใช้งานปัจจุบัน
  bool _isLoadingUser = true; // กำลังโหลดข้อมูลผู้ใช้
  StreamSubscription? _authSubscription; // ติดตามสถานะ Login/Logout

  bool _isConnected = true; // สถานะการเชื่อมต่ออินเทอร์เน็ต
  StreamSubscription? _connectivitySubscription; // ติดตามเน็ตหลุด/ต่อติด
  final FirebaseParkingService _parkingService = FirebaseParkingService();

  @override
  void initState() {
    super.initState();
    // เริ่มต้น listener ต่างๆ
    _listenToAuthChanges();
    _listenToConnectivityChanges();
  }

  @override
  void dispose() {
    // ยกเลิก listener เมื่อหน้านี้ถูกทำลาย
    _recSub?.cancel();
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ฟังก์ชันติดตามสถานะการ Login
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
          // ถ้า Login แล้ว ให้เช็คว่ามีการจองค้างไว้หรือไม่
          _checkExistingHold();
        } else {
          // ถ้า Logout ให้เคลียร์ข้อมูลการจองในเครื่อง
          setState(() {
            _recommendedSpotLocal = null;
          });
          _recSub?.cancel();
        }
      }
    });
  }

  // ฟังก์ชันติดตามสถานะการเชื่อมต่อเน็ต
  void _listenToConnectivityChanges() {
    // เช็คสถานะครั้งแรกทันที
    Connectivity().checkConnectivity().then(_updateConnectionStatus);
    // คอยฟังการเปลี่ยนแปลงตลอดเวลา
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  // อัปเดตตัวแปร _isConnected ตามผลลัพธ์
  void _updateConnectionStatus(dynamic value) {
    final List<ConnectivityResult> results;
    if (value is ConnectivityResult) {
      results = [value];
    } else if (value is List<ConnectivityResult>) {
      results = value;
    } else {
      results = const [ConnectivityResult.none];
    }

    if (!mounted) return;

    // ถือว่าต่อเน็ตได้ถ้าเป็น Mobile Data, Wifi หรือ Ethernet
    final connected = results.any((result) {
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet;
    });

    setState(() {
      _isConnected = connected;
    });
  }

  // เช็คว่า User นี้มีจองช่องไหนค้างไว้อยู่แล้วหรือไม่ (Recover State)
  Future<void> _checkExistingHold() async {
    final user = _currentUser;
    if (user == null) return;

    // เรียกไปถาม Firebase
    final existing = await _parkingService.getActiveHeldSpotId(user.uid);
    if (existing != null && mounted) {
      setState(() => _recommendedSpotLocal = existing);
      // ถ้ามีค้างอยู่ ให้เริ่มติดตามช่องนั้นต่อเลย
      _watchSpot(existing);
    }
  }

  // เริ่มกระบวนการค้นหาที่จอด (เปิดหน้า SearchingPage)
  Future<void> _startSearching() async {
    // ต้อง Login ก่อน
    if (_currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }
    if (_isSearching) return; // ป้องกันกดซ้ำ

    setState(() => _isSearching = true);
    try {
      // เปิดหน้าค้นหา รอผลลัพธ์ (ID ช่องที่แนะนำ)
      final resultSpotId = await Navigator.push<int?>(
        context,
        MaterialPageRoute(builder: (_) => const SearchingPage()),
      );

      // ถ้าได้ช่องกลับมา
      if (resultSpotId != null) {
        setState(() => _recommendedSpotLocal = resultSpotId);
        _watchSpot(resultSpotId); // เริ่มเฝ้าดูสถานะช่องนั้น
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // เฝ้าดูช่องที่ User จองไว้ (Real-time listener)
  void _watchSpot(int spotId) {
    _recSub?.cancel();
    _recSub = _parkingService.watchRecommendation(spotId).listen((
      recommendation,
    ) {
      // ถ้าสถานะการจอง "ไม่ Active" แล้ว (เช่น หมดเวลา, โดนแย่ง, หรือจอดสำเร็จ)
      if (!recommendation.isActive) {
        final msg = recommendation.reason ?? 'การจองสิ้นสุดลงแล้ว';
        if (mounted) {
          setState(() => _recommendedSpotLocal = null); // เคลียร์สถานะในหน้าจอ

          // แจ้งเตือนผู้ใช้ว่าการจองจบลงแล้ว
          _showRecommendationEndedDialog(
            msg,
            status: recommendation.spotStatus,
          );
        }
        _recSub?.cancel();
      }
    });
  }

  // Dialog แจ้งเมื่อการจองจบลง (เช่น หมดเวลา หรือมีคนจอด)
  Future<void> _showRecommendationEndedDialog(
    String message, {
    String? status,
  }) async {
    if (_isRecommendationDialogVisible || !mounted) return;

    _isRecommendationDialogVisible = true;
    final bool? retry = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              status == 'occupied' ? 'มีรถเข้าจอด' : 'การแนะนำเสร็จสิ้น',
            ),
            content: Text(
              status == 'occupied'
                  ? 'ช่องจอดถูกใช้งานแล้ว หากไม่ใช่ท่าน โปรดค้นหาใหม่'
                  : '$message\nถ้าต้องการค้นหาอีกครั้งให้กด "ค้นหาอีกครั้ง"',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // ปิด
                child: const Text('ปิด'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), // ค้นหาใหม่
                child: const Text('ค้นหาอีกครั้ง'),
              ),
            ],
          ),
    );
    _isRecommendationDialogVisible = false;

    // ถ้ากดค้นหาใหม่ ก็เริ่มค้นหาเลย
    if (retry == true && _isConnected) {
      _startSearching();
    }
  }

  // ยกเลิกการจองช่องปัจจุบัน (User กดเอง)
  Future<void> _cancelCurrentHold() async {
    if (_currentUser == null || _recommendedSpotLocal == null) return;
    final spotToCancel = _recommendedSpotLocal!;

    try {
      await _parkingService.cancelHold(spotToCancel);
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

  // เมื่อผู้ใช้แตะที่ช่องจอดบนแผนที่ (เพื่อจองเอง Manual)
  Future<void> _onSpotSelected(int spotId) async {
    // 1. ตรวจสอบ Login
    if (_currentUser == null) {
      final bool? shouldLogin = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('กรุณาเข้าสู่ระบบ'),
              content: const Text(
                'คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถจองช่องจอดได้',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('เข้าสู่ระบบ'),
                ),
              ],
            ),
      );

      if (shouldLogin == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    // 2. ตรวจสอบ Offline
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณกำลังออฟไลน์ ไม่สามารถจองได้')),
      );
      return;
    }

    // 3. ตรวจสอบว่าจองช่องอื่นค้างไว้อยู่ไหม
    if (_recommendedSpotLocal != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'คุณจองช่อง $_recommendedSpotLocal ไว้แล้ว กรุณายกเลิกก่อนจองใหม่',
          ),
        ),
      );
      return;
    }

    // 4. ถามยืนยัน
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('ยืนยันการจองช่อง $spotId'),
            content: const Text('คุณต้องการจองช่องจอดนี้ใช่หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // 5. ดำเนินการจอง
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กำลังดำเนินการจอง...')));

      await _parkingService.holdParkingSpot(spotId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // สำเร็จ -> อัปเดต state local
      setState(() => _recommendedSpotLocal = spotId);
      _watchSpot(spotId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('จองช่อง $spotId สำเร็จ!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('จองไม่สำเร็จ: $e')));
    }
  }

  // ส่วนแสดงเนื้อหาหลักของหน้า (แผนที่ + แถบสถานะด้านล่าง)
  Widget _buildHomePageContent(BuildContext context) {
    final bool isLoggedIn = _currentUser != null;
    final bool hasRecommendation = _recommendedSpotLocal != null;
    // เงื่อนไขที่จะกดปุ่มค้นหาได้
    final bool canSearch =
        isLoggedIn && !_isSearching && !hasRecommendation && _isConnected;

    return Stack(
      children: [
        // 1. แผนที่ลานจอด (ใช้พื้นที่ทั้งหมด)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: 100.0,
            ), // เว้นที่ให้แถบด้านล่าง
            child: ParkingMapLayout(
              // ถ้า Offline ไม่ต้องไฮไลต์ช่องแนะนำ
              recommendedSpot: _isConnected ? _recommendedSpotLocal : null,
              offlineMode: !_isConnected,
              onSpotSelected: _onSpotSelected,
            ),
          ),
        ),

        // 2. แถบควบคุมด้านล่าง (จำนวนว่าง + ปุ่มค้นหา)
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2.1 กล่องแสดงจำนวนที่ว่าง (Real-time Count)
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('parking_spots')
                        .where('status', isEqualTo: 'available')
                        .snapshots(),
                builder: (context, snapshot) {
                  final brightness = Theme.of(context).brightness;
                  final bgColor =
                      brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.9);
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
                      "พื้นที่ว่าง: $available/$kTotalSpots",
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

              // 2.2 กล่องแสดงสถานะการจอง (ถ้ามี)
              if (isLoggedIn && hasRecommendation)
                Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.9),
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
                          onPressed: _isConnected ? _cancelCurrentHold : null,
                          icon: Icon(
                            Icons.cancel,
                            color: _isConnected ? Colors.red : Colors.grey,
                          ),
                          label: Text(
                            'ยกเลิก',
                            style: TextStyle(
                              color: _isConnected ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 2.3 ปุ่มค้นหาที่จอดรถ
              if (_isLoadingUser)
                const CircularProgressIndicator()
              else if (isLoggedIn)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        canSearch
                            ? _startSearching
                            : null, // ปิดปุ่มถ้าไม่พร้อม
                    child: Text(
                      _isSearching
                          ? 'กำลังค้นหา...'
                          : (hasRecommendation
                              ? 'คุณมีช่องจอดที่แนะนำแล้ว' // ถ้ามีจองอยู่ ห้ามค้นหาใหม่
                              : (_isConnected
                                  ? 'ค้นหาที่จอดรถ'
                                  : 'Offline')), // ถ้า Offline ห้ามค้นหา
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 3. ป้ายเตือน Offline (แสดงด้านบนสุด)
        if (!_isConnected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.red.shade700,
              elevation: 2,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(
                  'คุณกำลังออฟไลน์ ไม่สามารถใช้งานฟังก์ชันจองได้',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // หน้าทั้งหมดใน Navigation Stack (Home, Profile)
    final List<Widget> pages = [
      _buildHomePageContent(context),
      _currentUser != null ? const ProfilePage() : const LoginPage(),
    ];

    return AdaptiveScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Pak Nhai'),
        actions: [
          // ปุ่ม Help
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'คำแนะนำการใช้งาน',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InstructionPage()),
              );
            },
          ),

          // ปุ่ม Profile / Login
          if (_isLoadingUser)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'โปรไฟล์',
              onPressed:
                  _isConnected
                      ? () {
                        setState(() => _currentIndex = 1); // สลับไป Tab Profile
                      }
                      : null, // ห้ามเข้า Profile ถ้า Offline
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed:
                    _isConnected
                        ? () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        )
                        : null,
                child: const Text('เข้าสู่ระบบ'),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      currentIndex: _currentIndex,
      destinations: const [
        AdaptiveNavigationItem(icon: Icons.home, label: 'หน้าหลัก'),
        AdaptiveNavigationItem(icon: Icons.person, label: 'โปรไฟล์'),
      ],
      onDestinationSelected: (index) {
        // ห้ามไปหน้า Profile ถ้า Offline
        if (index == 1 && !_isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('คุณกำลังออฟไลน์ ไม่สามารถดูโปรไฟล์ได้'),
            ),
          );
          return;
        }

        if (index == 1 && _currentUser == null) {
          // ถ้ากด Profile แต่ยังไม่ Login ให้เด้งไปหน้า Login
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        } else {
          setState(() => _currentIndex = index);
        }
      },
    );
  }
}
