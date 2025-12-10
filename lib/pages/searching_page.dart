// lib/pages/searching_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mtproject/services/firebase_parking_service.dart';
import 'package:mtproject/ui/recommend_dialog.dart';

// =================================================================================
// หน้าค้นหาที่จอด (SEARCHING PAGE)
// =================================================================================
// หน้าแสดงสถานะการ Loading ระหว่างรอระบบแนะนำช่องจอด

class SearchingPage extends StatefulWidget {
  const SearchingPage({super.key});

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage> {
  final FirebaseParkingService _parkingService = FirebaseParkingService();
  bool _done = false; // ตัวแปรป้องกันการ Pop ซ้ำซ้อน

  @override
  void initState() {
    super.initState();
    _startSearching(); // เริ่มค้นหาทันทีเมื่อเข้ามาหน้านี้
  }

  Future<void> _startSearching() async {
    try {
      // เรียกฟังก์ชันแนะนำช่องจอด (รอสูงสุด 10 วินาที)
      final RecommendationResult? result = await _parkingService
          .recommendAndHoldClient(holdSeconds: 900) // จองไว้ 15 นาที
          .timeout(const Duration(seconds: 10));

      if (mounted && !_done) {
        if (result != null) {
          _done = true; // มาร์คว่าเสร็จแล้ว

          // แสดง Dialog แจ้งผลการแนะนำ
          await showRecommendDialog(
            context,
            recommendedIds: [result.spotId],
            helperMessage:
                result.reusedExistingHold
                    ? 'คุณมีการจองเดิมที่ยังไม่หมดเวลา'
                    : null,
          );

          // เมื่อปิด Dialog ให้กลับไปหน้า Home พร้อมส่ง ID ช่องจอดกลับไป
          if (mounted) {
            Navigator.pop<int>(context, result.spotId);
          }
        } else {
          // กรณีไม่ได้รับผลลัพธ์ (เช่น เต็มหมด)
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

  // กลับไปหน้าเดิมโดยไม่มีผลลัพธ์
  void _backWithoutSpot() {
    _done = true;
    Navigator.pop<int?>(context, null);
  }

  // helper สำหรับแสดง SnackBar
  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(), // หมุนติ้วๆ
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
