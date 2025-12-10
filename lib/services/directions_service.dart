import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// พิกัดปลายทาง: ตึก 6 ม.อ.ภูเก็ต (กำหนดค่าตายตัว)
const _destLat = 7.893474020477164;
const _destLng = 98.35215685845772;

/// ฟังก์ชันขอสิทธิ์และอ่านตำแหน่งปัจจุบัน GPS
Future<Position> _getCurrentPosition() async {
  // 1. ตรวจสอบสิทธิ์การเข้าถึงตำแหน่ง
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  // ถ้าผุ้ใช้ปฏิเสธถาวร จะไม่สามารถทำต่อได้
  if (perm == LocationPermission.deniedForever) {
    throw Exception('โปรดเปิดสิทธิ์ตำแหน่งใน Settings');
  }

  // 2. ตรวจสอบว่าเปิด GPS หรือยัง
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    throw Exception('โปรดเปิด Location Service (GPS)');
  }

  // 3. อ่านค่าปัจจุบัน (ใช้ความแม่นยำสูงสุด)
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
  );
}

/// ฟังก์ชันเปิด Google Maps นำทางไปยัง ม.อ.ภูเก็ต
/// (ใช้ External Application Launcher)
Future<void> openGoogleMapsToPSUPK() async {
  // หาตำแหน่งต้นทาง (ตำแหน่งเรา)
  final pos = await _getCurrentPosition();
  final originLat = pos.latitude;
  final originLng = pos.longitude;

  // สร้าง URL สำหรับเปิด Google Maps
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=$originLat,$originLng'
    '&destination=$_destLat,$_destLng'
    '&travelmode=driving', // โหมดขับรถ
  );

  // สั่งเปิด URL (ถ้าเปิดไม่ได้ให้แจ้ง Error)
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('ไม่สามารถเปิด Google Maps ได้');
  }
}
