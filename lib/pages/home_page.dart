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
import 'package:mtproject/ui/adaptive_scaffold.dart'; // Import adaptive_scaffold
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mtproject/pages/instruction_page.dart';

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
  bool _isRecommendationDialogVisible = false;

  User? _currentUser;
  bool _isLoadingUser = true;
  StreamSubscription? _authSubscription;

  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;
  final FirebaseParkingService _parkingService = FirebaseParkingService();

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
    _listenToConnectivityChanges();
  }

  @override
  void dispose() {
    _recSub?.cancel();
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
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

  void _listenToConnectivityChanges() {
    // เช็คสถานะครั้งแรกตอนเปิดหน้า
    Connectivity().checkConnectivity().then(_updateConnectionStatus);
    // คอยฟังการเปลี่ยนแปลง
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  // Helper function สำหรับอัปเดต state
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
    final connected = results.any((result) {
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet;
    });
    setState(() {
      _isConnected = connected;
    });
  }

  Future<void> _checkExistingHold() async {
    final user = _currentUser;
    if (user == null) return;
    final existing = await _parkingService.getActiveHeldSpotId(user.uid);
    if (existing != null && mounted) {
      setState(() => _recommendedSpotLocal = existing);
      _watchSpot(existing);
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
    _recSub = _parkingService.watchRecommendation(spotId).listen((
      recommendation,
    ) {
      if (!recommendation.isActive) {
        final msg = recommendation.reason ?? 'การจองสิ้นสุดลงแล้ว';
        if (mounted) {
          setState(() => _recommendedSpotLocal = null);
          // แจ้งเตือนผู้ใช้ทันทีเมื่อ Cloud Firestore แจ้งว่าการแนะนำหมดอายุหรือถูกยกเลิก
          _showRecommendationEndedDialog(
            msg,
            status: recommendation.spotStatus,
          );
        }
        _recSub?.cancel();
      }
    });
  }

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
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ปิด'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ค้นหาอีกครั้ง'),
              ),
            ],
          ),
    );
    _isRecommendationDialogVisible = false;
    if (retry == true && _isConnected) {
      _startSearching();
    }
  }

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

  Future<void> _onSpotSelected(int spotId) async {
    // 1. Check Login
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

    // 2. Check Connection
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณกำลังออฟไลน์ ไม่สามารถจองได้')),
      );
      return;
    }

    // 3. Check Existing Hold
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

    // 4. Confirm Dialog
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

    // 5. Perform Hold
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กำลังดำเนินการจอง...')));

      await _parkingService.holdParkingSpot(spotId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

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

  // --- _buildHomePageContent (เหมือนเดิมจากครั้งที่แล้ว) ---
  Widget _buildHomePageContent(BuildContext context) {
    final bool isLoggedIn = _currentUser != null;
    final bool hasRecommendation = _recommendedSpotLocal != null;
    final bool canSearch =
        isLoggedIn && !_isSearching && !hasRecommendation && _isConnected;

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100.0),
            child: ParkingMapLayout(
              // เมื่อออฟไลน์ เราแสดงผังสีเทาและไม่ให้ไฮไลต์ช่องใด ๆ
              recommendedSpot: _isConnected ? _recommendedSpotLocal : null,
              offlineMode: !_isConnected,
              onSpotSelected: _onSpotSelected,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                          // ปิดปุ่มเมื่อ Offline
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

              // VVV 9. ปรับแก้ปุ่มค้นหา VVV
              if (_isLoadingUser)
                const CircularProgressIndicator()
              else if (isLoggedIn)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        canSearch ? _startSearching : null, // <-- ใช้ canSearch
                    child: Text(
                      _isSearching
                          ? 'กำลังค้นหา...'
                          : (hasRecommendation
                              ? 'คุณมีช่องจอดที่แนะนำแล้ว'
                              : (_isConnected
                                  ? 'ค้นหาที่จอดรถ'
                                  : 'Offline')), // <-- เปลี่ยนข้อความ
                    ),
                  ),
                ),
            ],
          ),
        ),

        // VVV 10. เพิ่มแถบเตือน Offline VVV
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
    final List<Widget> pages = [
      _buildHomePageContent(context),
      _currentUser != null ? const ProfilePage() : const LoginPage(),
    ];

    return AdaptiveScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Pak Nhai'),
        // VVV 11. ปิดปุ่ม Profile ถ้า Offline VVV
        actions: [
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
              // ปิดปุ่มเมื่อ Offline
              onPressed:
                  _isConnected
                      ? () {
                        setState(() => _currentIndex = 1);
                      }
                      : null,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                // ปิดปุ่มเมื่อ Offline
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
        // VVV 12. ปิดการไปหน้า Profile ถ้า Offline VVV
        if (index == 1 && !_isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('คุณกำลังออฟไลน์ ไม่สามารถดูโปรไฟล์ได้'),
            ),
          );
          return; // ไม่ต้องทำอะไร
        }

        if (index == 1 && _currentUser == null) {
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
