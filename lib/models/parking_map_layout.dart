// lib/models/parking_map_layout.dart
import 'package:flutter/material.dart';
// 1. Import config file
import 'package:mtproject/models/parking_layout_config.dart';
import 'parking_box.dart';

// 2. ลบ Class ParkingLayoutInfo และ List kParkingLayoutXY ที่เคยย้ายมาทิ้งไป

class ParkingMapLayout extends StatelessWidget {
  final int? recommendedSpot;
  final bool offlineMode;

  const ParkingMapLayout({
    super.key,
    this.recommendedSpot,
    this.offlineMode = false,
  }) : assert(
         kParkingLayoutXY.length == kTotalParkingSpots,
         'Parking layout must list all $kTotalParkingSpots spots.',
       );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final roadColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return InteractiveViewer(
      maxScale: 3.0,
      minScale: 0.1,
      // boundaryMargin: const EdgeInsets.all(double.infinity),
      child: Container(
        color: backgroundColor,
        width: 800,
        // 3. ใช้ความสูงที่คำนวณจาก config
        height: kMapTotalHeight,
        child: Stack(
          children: [
            // 4. ใช้ const ตำแหน่งถนนจาก config
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
                width: kRoadHeight, // 40
                height: kRoadVerticalHeight, // 470
                color: roadColor,
              ),
            ),
            // ถนนแนวตั้งขวา
            Positioned(
              top: kRoadTopY,
              left: kRoadRightX,
              child: Container(
                width: kRoadHeight, // 40
                height: kRoadVerticalHeight, // 470
                color: roadColor,
              ),
            ),

            // 5. Loop นี้จะใช้ kParkingLayoutXY ที่ import มา
            // ซึ่งมีพิกัด y ที่ถูกขยับขึ้นแล้ว
            for (final spotInfo in kParkingLayoutXY)
              Positioned(
                top: spotInfo.y,
                left: spotInfo.x,
                child: ParkingBox(
                  docId: '${spotInfo.id}',
                  id: spotInfo.id,
                  direction: spotInfo.direction,
                  recommendedId: recommendedSpot,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
