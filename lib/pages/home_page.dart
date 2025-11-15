// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/models/parking_map_layout.dart';
import 'package:mtproject/pages/login_page.dart';
import 'package:mtproject/pages/profile_page.dart';

import 'package:mtproject/pages/searching_page.dart';
import 'package:mtproject/services/firebase_parking_service.dart';
import 'package:mtproject/ui/adaptive_scaffold.dart';

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
    Widget _buildHomePageContent(BuildContext context) {
    final bool isDesktop = AdaptiveScaffold.useDesktopLayout(context);
    return isDesktop
        ? _buildDesktopHomeContent(context)
        : _buildMobileHomeContent(context);
  }

  Widget _buildDesktopHomeContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Card(
              elevation: 2,
              clipBehavior: Clip.hardEdge,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ParkingMapLayout(
                  recommendedSpot: _recommendedSpotLocal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAvailabilityStatus(context, isDesktop: true),
                  const SizedBox(height: 16),
                  if (_currentUser != null && _recommendedSpotLocal != null)
                    _buildRecommendationCard(context, isDesktop: true),
                  const SizedBox(height: 24),
                  _buildPrimaryActionButton(context, isDesktop: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHomeContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ParkingMapLayout(
                recommendedSpot: _recommendedSpotLocal,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildAvailabilityStatus(context, isDesktop: false),
        const SizedBox(height: 12),
        if (_currentUser != null && _recommendedSpotLocal != null)
          _buildRecommendationCard(context, isDesktop: false),
        const SizedBox(height: 16),
        _buildPrimaryActionButton(context, isDesktop: false),
      ],
    );
  }

  Widget _buildAvailabilityStatus(BuildContext context,
      {required bool isDesktop}) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final errorColor = theme.colorScheme.error;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parking_spots')
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        String message;
        Color textColor = onSurface;

        if (snapshot.connectionState == ConnectionState.waiting) {
          message = 'กำลังโหลด...';
        } else if (snapshot.hasError) {
          message = 'โหลดข้อมูลไม่ได้';
          textColor = errorColor;
        } else {
          final available = snapshot.data?.docs.length ?? 0;
          message = 'พื้นที่ว่าง: $available/52';
        }

        return Card(
          elevation: isDesktop ? 1 : 4,
          color: theme.colorScheme.surfaceVariant,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(color: textColor),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationCard(BuildContext context,
      {required bool isDesktop}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: isDesktop ? 1 : 3,
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'แนะนำช่อง: $_recommendedSpotLocal',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(
                  Icons.cancel,
                  color: colorScheme.error,
                ),
                label: const Text('ยกเลิก'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
                onPressed: _cancelCurrentHold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActionButton(BuildContext context,
      {required bool isDesktop}) {
    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isLoggedIn = _currentUser != null;
    final bool hasRecommendation = _recommendedSpotLocal != null;

    VoidCallback? onPressed;
    String label;

    if (!isLoggedIn) {
      onPressed = () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      };
      label = 'เข้าสู่ระบบเพื่อค้นหาที่จอด';
    } else if (_isSearching) {
      onPressed = null;
      label = 'กำลังค้นหา...';
    } else if (hasRecommendation) {
      onPressed = null;
      label = 'คุณมีช่องจอดที่แนะนำแล้ว';
    } else {
      onPressed = _startSearching;
      label = 'ค้นหาที่จอดรถ';
    }

    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 48 : 50,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
  // =================================================================
  //  ^^^      สิ้นสุดการแก้ไข _buildHomePageContent      ^^^
  // =================================================================

  @override
  Widget build(BuildContext context) {
    // --- สร้าง List ของหน้าต่างๆ (เหมือนเดิม) ---
    final List<Widget> pages = [
       _buildHomePageContent(context),
      _currentUser != null ? const ProfilePage() : const LoginPage(),
    ];

    return AdaptiveScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Smart Parking'),
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      currentIndex: _currentIndex,
      destinations: const [
        AdaptiveNavigationItem(icon: Icons.home, label: 'หน้าหลัก'),
        AdaptiveNavigationItem(icon: Icons.person, label: 'โปรไฟล์'),
      ],
      onDestinationSelected: (index) {
        if (index == 1 && _currentUser == null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
          return;
        }
        setState(() => _currentIndex = index);
      },
    );
  }
}
