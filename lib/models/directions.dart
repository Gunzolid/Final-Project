import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// [NOTE] ไฟล์นี้อาจจะซ้ำซ้อนกับ services/directions_service.dart
// แต่ถ้ามีการเรียกใช้จาก Models ก็เก็บไว้ได้

const _destLat = 7.893474020477164;
const _destLng = 98.35215685845772;

/// ขอสิทธิ์ + อ่านตำแหน่งปัจจุบัน
Future<Position> _getCurrentPosition() async {
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.deniedForever) {
    throw Exception('โปรดเปิดสิทธิ์ตำแหน่งใน Settings');
  }
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    throw Exception('โปรดเปิด Location Service (GPS)');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
  );
}

/// เปิดเส้นทางไป "ตึก 6 ม.อ.ภูเก็ต" บน Google Maps
Future<void> openGoogleMapsToPSUPK() async {
  final pos = await _getCurrentPosition();
  final originLat = pos.latitude;
  final originLng = pos.longitude;

  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=$originLat,$originLng'
    '&destination=$_destLat,$_destLng'
    '&travelmode=driving',
  );

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('ไม่สามารถเปิด Google Maps ได้');
  }
}
