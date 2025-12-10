// lib/models/parking_spot.dart

/// คลาสสำหรับเก็บข้อมูลช่องจอดแบบย่อ (Simple Data Model)
class ParkingSpot {
  final int id; // หมายเลขช่องจอด
  final bool isAvailable; // สถานะ (ว่าง/ไม่ว่าง)

  ParkingSpot({required this.id, required this.isAvailable});
}
