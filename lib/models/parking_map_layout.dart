// lib/models/parking_map_layout.dart
import 'package:flutter/material.dart';

// 1. Import config file
import 'package:mtproject/models/parking_layout_config.dart';
import 'parking_box.dart';

// 2. ลบ Class ParkingLayoutInfo และ List kParkingLayoutXY ที่เคยย้ายมาทิ้งไป

import 'package:mtproject/models/admin_parking_box.dart';

class ParkingMapLayout extends StatefulWidget {
  final int? recommendedSpot;
  final bool offlineMode;
  final bool isAdmin;
  final Function(int)? onSpotSelected;

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
    // Center the map after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMap();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _centerMap() {
    if (!mounted) return;

    // Calculate scale to fit width or height, or just use 1.0
    // Let's stick to 1.0 or slightly smaller if screen is small, but user wants to pan.
    // Let's start with scale 1.0 (or minScale) and center it.

    // Center X: (ScreenW - MapW) / 2
    // Center Y: (ScreenH - MapH) / 2
    // But InteractiveViewer uses a Matrix4.
    // Translation is negative to move the content "left/up" into view if it's larger than screen?
    // Actually, if content is larger, we want to shift it so its center matches screen center.

    final double x = 25;
    final double y = 10;

    _transformationController.value = Matrix4.identity()..translate(x, y, 0.0);
  }

  @override
  Widget build(BuildContext context) {
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
      maxScale: 3.0,
      minScale: 0.1,
      // Allow panning past the edges
      boundaryMargin: const EdgeInsets.all(10),
      constrained:
          false, // Allow the child to be its natural size (1200xHeight)
      child: Container(
        color: backgroundColor,
        width: 1200, // Increased width for wider layout
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
                child:
                    widget.isAdmin
                        ? AdminParkingBox(
                          docId: '${spotInfo.id}',
                          id: spotInfo.id,
                          direction: spotInfo.direction,
                        )
                        : ParkingBox(
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

            // 6. แสดงลูกศรบอกทาง
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
