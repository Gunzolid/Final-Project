import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

const _destLat = 7.893474020477164;
const _destLng = 98.35215685845772;

/// ขอสิทธิ์ + อ่านตำแหน่งปัจจุบันแบบง่าย
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
  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
}

/// เปิดเส้นทางไป "ตึก 6 ม.อ.ภูเก็ต" บน Google Maps (ฟรี)
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
