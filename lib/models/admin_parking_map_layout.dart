// lib/models/admin_parking_map_layout.dart
import 'package:flutter/material.dart';
// 1. Import config file
import 'package:mtproject/models/parking_layout_config.dart';
import 'admin_parking_box.dart';

class AdminParkingMapLayout extends StatelessWidget {
  const AdminParkingMapLayout({super.key});
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final roadColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return InteractiveViewer(
      maxScale: 3.0,
      minScale: 0.1,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: Container(
        width: 800,
        // 2. ใช้ความสูงที่คำนวณจาก config
        height: kMapTotalHeight,
        color: backgroundColor,
        child: Stack(
          children: [
            // 3. ใช้ const ตำแหน่งถนนจาก config
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

            // 4. Loop นี้จะใช้ kParkingLayoutXY ที่ import มา
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
