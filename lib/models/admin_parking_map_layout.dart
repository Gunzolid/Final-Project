// lib/models/admin_parking_map_layout.dart
import 'package:flutter/material.dart';
import 'package:mtproject/models/parking_layout_config.dart';
import 'admin_parking_box.dart';

// =================================================================================
// แผนที่ลานจอดสำหรับ Admin (ADMIN MAP LAYOUT)
// =================================================================================

class AdminParkingMapLayout extends StatelessWidget {
  const AdminParkingMapLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // กำหนดสีถนนตาม Theme
    final brightness = Theme.of(context).brightness;
    final roadColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return InteractiveViewer(
      maxScale: 3.0,
      minScale: 0.1,
      boundaryMargin: const EdgeInsets.all(double.infinity), // เลื่อนได้อิสระ
      child: Container(
        width: 800,
        height: kMapTotalHeight, // ความสูงจาก Config
        color: backgroundColor,
        child: Stack(
          children: [
            // =========================================================
            // ส่วนที่ 1: วาดถนน
            // =========================================================

            // ถนนแนวนอนบน
            Positioned(
              top: kRoadTopY,
              left: kRoadLeftX,
              child: Container(
                width: kRoadHorizontalWidth,
                height: kRoadHeight,
                color: roadColor,
              ),
            ),
            // ถนนแนวนอนล่าง
            Positioned(
              top: kRoadBottomY,
              left: kRoadLeftX,
              child: Container(
                width: kRoadHorizontalWidth,
                height: kRoadHeight,
                color: roadColor,
              ),
            ),
            // ถนนแนวตั้งซ้าย
            Positioned(
              top: kRoadTopY,
              left: kRoadLeftX,
              child: Container(
                width: kRoadHeight,
                height: kRoadVerticalHeight,
                color: roadColor,
              ),
            ),
            // ถนนแนวตั้งขวา
            Positioned(
              top: kRoadTopY,
              left: kRoadRightX,
              child: Container(
                width: kRoadHeight,
                height: kRoadVerticalHeight,
                color: roadColor,
              ),
            ),

            // =========================================================
            // ส่วนที่ 2: วาดช่องจอด (ใช้ AdminParkingBox)
            // =========================================================
            for (final spotInfo in kParkingLayoutXY)
              Positioned(
                top: spotInfo.y,
                left: spotInfo.x,
                child: AdminParkingBox(
                  docId: '${spotInfo.id}',
                  id: spotInfo.id,
                  direction: spotInfo.direction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
