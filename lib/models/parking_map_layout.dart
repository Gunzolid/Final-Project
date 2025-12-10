// lib/models/parking_map_layout.dart
import 'package:flutter/material.dart';
import 'package:mtproject/models/parking_layout_config.dart';
import 'parking_box.dart';
import 'package:mtproject/models/admin_parking_box.dart';

// =================================================================================
// วิดเจ็ตแผนที่ลานจอด (MAP LAYOUT)
// =================================================================================

class ParkingMapLayout extends StatefulWidget {
  final int? recommendedSpot; // ช่องที่แนะนำ (ถ้ามี จะถูก highlight)
  final bool offlineMode; // โหมดออฟไลน์
  final bool isAdmin; // เป็น Admin หรือไม่ (ถ้าใช่จะแสดง AdminBox)
  final Function(int)? onSpotSelected; // Callback เมื่อเลือกช่องจอด

  const ParkingMapLayout({
    super.key,
    this.recommendedSpot,
    this.offlineMode = false,
    this.isAdmin = false,
    this.onSpotSelected,
  });

  @override
  State<ParkingMapLayout> createState() => _ParkingMapLayoutState();
}

class _ParkingMapLayoutState extends State<ParkingMapLayout> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    // จัดให้แผนที่อยู่กึ่งกลางเมื่อโหลดเสร็จ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMap();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // ฟังก์ชันจัดตำแหน่งเริ่มต้นของแผนที่
  void _centerMap() {
    if (!mounted) return;

    // ตั้งค่าเริ่มต้นการเลื่อน (Translation)
    final double x = 25;
    final double y = 10;
    _transformationController.value = Matrix4.identity()..translate(x, y, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // ต้องมีข้อมูลช่องจอดครบตามจำนวนที่กำหนด
    assert(
      kParkingLayoutXY.length == kTotalSpots,
      'Parking layout must list all $kTotalSpots spots.',
    );

    final brightness = Theme.of(context).brightness;
    final roadColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return InteractiveViewer(
      transformationController: _transformationController,
      maxScale: 3.0, // ซูมได้สูงสุด 3 เท่า
      minScale: 0.1, // ซูมออกได้เล็กสุด 0.1 เท่า
      boundaryMargin: const EdgeInsets.all(10), // ขอบเขตการเลื่อน
      constrained:
          false, // ปล่อยให้ขนาดแผนที่เป็นไปตามจริง (ไม่บีบให้เท่าหน้าจอ)
      child: Container(
        color: backgroundColor,
        width: 1200, // ความกว้างพื้นที่วาด
        height: kMapTotalHeight, // ความสูงพื้นที่วาด (จาก Config)
        child: Stack(
          children: [
            // =========================================================
            // ส่วนที่ 1: วาดถนน (ROADS)
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
            // ส่วนที่ 2: วาดช่องจอดรถ (PARKING SPOTS)
            // =========================================================

            // วนลูปวาดตามพิกัดที่กำหนดใน Config
            for (final spotInfo in kParkingLayoutXY)
              Positioned(
                top: spotInfo.y,
                left: spotInfo.x,
                child:
                    widget.isAdmin
                        ? AdminParkingBox(
                          // ถ้าเป็น Admin ใช้กล่องควบคุมแบบ Admin
                          docId: '${spotInfo.id}',
                          id: spotInfo.id,
                          direction: spotInfo.direction,
                        )
                        : ParkingBox(
                          // ถ้าเป็น User ทั่วไป แสดงสถานะปกติ
                          docId: '${spotInfo.id}',
                          id: spotInfo.id,
                          direction: spotInfo.direction,
                          recommendedId: widget.recommendedSpot,
                          offlineMode: widget.offlineMode,
                          onSelect:
                              widget.onSpotSelected != null
                                  ? () => widget.onSpotSelected!(spotInfo.id)
                                  : null,
                        ),
              ),

            // =========================================================
            // ส่วนที่ 3: วาดลูกศรบอกทิศทาง (DIRECTION ARROWS)
            // =========================================================
            for (final arrow in kParkingArrows)
              Positioned(
                top: arrow.y,
                left: arrow.x,
                child: Transform.rotate(
                  angle: arrow.angle,
                  child: Icon(
                    Icons.arrow_forward,
                    color:
                        brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
