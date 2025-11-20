import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mtproject/services/firebase_parking_service.dart';
import 'package:mtproject/ui/recommend_dialog.dart';

class SearchingPage extends StatefulWidget {
  const SearchingPage({super.key});

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage> {
  final FirebaseParkingService _parkingService = FirebaseParkingService();
  bool _done = false; // กัน pop ซ้ำ

  @override
  void initState() {
    super.initState();
    _startSearching();
  }

  Future<void> _startSearching() async {
    try {
      final RecommendationResult? result = await _parkingService
          .recommendAndHoldClient(holdSeconds: 900)
          .timeout(const Duration(seconds: 10));

      if (mounted && !_done) {
        if (result != null) {
          _done = true; // ตั้งค่าว่าเสร็จสิ้นแล้ว

          // =================================================================
          //  VVV      จุดแก้ไข: เรียกใช้ฟังก์ชัน และส่ง List<int>      VVV
          // =================================================================
          // แสดง Dialog แนะนำ
          await showRecommendDialog(
            context,
            recommendedIds: [result.spotId],
            helperMessage:
                result.reusedExistingHold
                    ? 'คุณมีการจองเดิมที่ยังไม่หมดเวลา'
                    : null,
          );

          // หลังจาก Dialog ปิด ให้ Pop กลับไปหน้า Home
          if (mounted) {
            Navigator.pop<int>(context, result.spotId);
          }
          // =================================================================
        } else {
          _show('ขออภัย ขณะนี้ไม่มีช่องจอดว่าง');
          _backWithoutSpot();
        }
      }
    } catch (e) {
      if (mounted && !_done) {
        _show('เกิดข้อผิดพลาดในการค้นหา: $e');
        _backWithoutSpot();
      }
    }
  }

  // void _noSpotAndBack() {
  //   _show('ขณะนี้ไม่มีช่องว่าง');
  //   _backWithoutSpot();
  // }

  void _backWithoutSpot() {
    _done = true;
    Navigator.pop<int?>(context, null); // ✅ กลับโดยไม่มีผลลัพธ์
  }

  void _show(String msg) {
    // แสดงบนหน้านี้ก่อน pop (ถ้าอยากให้ไปโผล่ที่ Home ให้ย้ายไปแสดงหลังรับผลลัพธ์แทน)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "กำลังค้นหาที่จอดรถ...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
