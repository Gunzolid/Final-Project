import 'package:flutter/material.dart';

// --- ค่าคงที่สำหรับ Layout ---
const int kTotalSpots = 52;
const double kLayoutVerticalShift = 40.0;

/// -----------------------------------------------------------------

// --- ตำแหน่งถนน (คำนวณอัตโนมัติ) ---
const double kRoadTopY = 100.0 - kLayoutVerticalShift;
const double kRoadBottomY = 570.0 - kLayoutVerticalShift;
const double kRoadLeftX = 50.0;
const double kRoadRightX = 270.0;
const double kRoadHorizontalWidth = 300.0;
const double kRoadVerticalHeight = 470.0; // 570 - 100
const double kRoadHeight = 40.0;
const double kMapTotalHeight = 1400.0; // ความสูงรวมของแผนที่

// --- Class ข้อมูลตำแหน่ง ---
class ParkingLayoutInfo {
  final int id;
  final double x; // left
  final double y; // top
  final Axis direction;

  const ParkingLayoutInfo({
    required this.id,
    required this.x,
    required this.y,
    this.direction = Axis.vertical,
  });
}

// --- List พิกัดช่องจอด (คำนวณอัตโนมัติ) ---
// (พิกัด y ทั้งหมดจะถูกลบด้วย kLayoutVerticalShift)
const List<ParkingLayoutInfo> kParkingLayoutXY = [
  ParkingLayoutInfo(id: 1, x: 195, y: 140 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 2, x: 165, y: 140 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 3, x: 135, y: 140 - kLayoutVerticalShift),
  ParkingLayoutInfo(
    id: 4,
    x: 90,
    y: 150 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 5,
    x: 90,
    y: 180 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 6,
    x: 90,
    y: 230 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 7,
    x: 90,
    y: 260 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 8,
    x: 90,
    y: 290 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 9,
    x: 90,
    y: 380 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 10,
    x: 90,
    y: 410 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 11,
    x: 90,
    y: 440 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 12,
    x: 90,
    y: 500 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 13,
    x: 90,
    y: 530 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(id: 14, x: 135, y: 520 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 15, x: 165, y: 520 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 16, x: 195, y: 520 - kLayoutVerticalShift),
  ParkingLayoutInfo(
    id: 17,
    x: 225,
    y: 530 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 18,
    x: 225,
    y: 500 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 19,
    x: 225,
    y: 440 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 20,
    x: 225,
    y: 410 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 21,
    x: 225,
    y: 380 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 22,
    x: 225,
    y: 290 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 23,
    x: 225,
    y: 260 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 24,
    x: 225,
    y: 230 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 25,
    x: 225,
    y: 180 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 26,
    x: 225,
    y: 150 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(id: 27, x: 130, y: 50 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 28, x: 100, y: 50 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 29, x: 70, y: 50 - kLayoutVerticalShift),
  ParkingLayoutInfo(
    id: 30,
    x: 5,
    y: 150 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 31,
    x: 5,
    y: 180 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 32,
    x: 5,
    y: 230 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 33,
    x: 5,
    y: 260 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 34,
    x: 5,
    y: 290 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 35,
    x: 5,
    y: 380 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 36,
    x: 5,
    y: 410 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 37,
    x: 5,
    y: 440 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 38,
    x: 5,
    y: 500 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 39,
    x: 5,
    y: 530 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(id: 40, x: 70, y: 615 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 41, x: 100, y: 615 - kLayoutVerticalShift),
  ParkingLayoutInfo(id: 42, x: 130, y: 615 - kLayoutVerticalShift),
  ParkingLayoutInfo(
    id: 43,
    x: 310,
    y: 530 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 44,
    x: 310,
    y: 500 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 45,
    x: 310,
    y: 440 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 46,
    x: 310,
    y: 410 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 47,
    x: 310,
    y: 380 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 48,
    x: 310,
    y: 290 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 49,
    x: 310,
    y: 260 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 50,
    x: 310,
    y: 230 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 51,
    x: 310,
    y: 180 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
  ParkingLayoutInfo(
    id: 52,
    x: 310,
    y: 150 - kLayoutVerticalShift,
    direction: Axis.horizontal,
  ),
];

// --- Class ข้อมูลลูกศรบอกทาง ---
class ParkingArrowInfo {
  final double x;
  final double y;
  final double
  angle; // มุมหมุน (radian) 0 = หัวชี้ไปทางขวา, pi/2 = ลง, pi = ซ้าย, -pi/2 = ขึ้น

  const ParkingArrowInfo({
    required this.x,
    required this.y,
    required this.angle,
  });
}

// --- List พิกัดลูกศร (ตัวอย่าง) ---
const List<ParkingArrowInfo> kParkingArrows = [
  // ถนนแนวตั้งซ้าย (ชี้ลง)
  ParkingArrowInfo(x: kRoadLeftX + 6, y: 150, angle: 1.57), // pi/2
  ParkingArrowInfo(x: kRoadLeftX + 6, y: 300, angle: 1.57),
  ParkingArrowInfo(x: kRoadLeftX + 6, y: 450, angle: 1.57),

  // ถนนแนวตั้งขวา (ชี้ขึ้น)
  ParkingArrowInfo(x: kRoadRightX + 7, y: 450, angle: -1.57), // -pi/2
  ParkingArrowInfo(x: kRoadRightX + 7, y: 300, angle: -1.57),
  ParkingArrowInfo(x: kRoadRightX + 7, y: 150, angle: -1.57),

  // ถนนแนวนอนบน (ชี้ขวา)
  ParkingArrowInfo(x: 120, y: kRoadBottomY + 10, angle: 0),
  ParkingArrowInfo(x: 200, y: kRoadBottomY + 10, angle: 0),
  ParkingArrowInfo(x: 320, y: kRoadBottomY + 10, angle: 0),

  // ถนนแนวนอนล่าง (ชี้ซ้าย)
  ParkingArrowInfo(x: 200, y: kRoadTopY + 10, angle: 3.14), // pi
  ParkingArrowInfo(x: 120, y: kRoadTopY + 10, angle: 3.14),
  ParkingArrowInfo(x: 320, y: kRoadTopY + 10, angle: 3.14),
];
