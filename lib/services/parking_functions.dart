import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingFunctions {
  static final _functions = FirebaseFunctions.instance;

  /// ฟังก์ชันสำหรับเรียก Cloud Function "recommendAndHold"
  /// เพื่อให้เซิร์ฟเวอร์คำนวณหาช่องจอดที่ว่างและจองให้เรา
  static Future<({String docId, int id, DateTime? holdExpiresAt})?> recommend({
    int entryX = 0,
    int entryY = 0,
    int holdSeconds = 900, // ค่า Time-out เริ่มต้น 15 นาที (900 วินาที)
  }) async {
    // ต้องมี User ID ส่งไปด้วยเสมอ
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // เรียกฟังก์ชัน HTTPS Callable ชื่อ 'recommendAndHold' บน Firebase
    final callable = _functions.httpsCallable('recommendAndHold');
    final res = await callable.call({
      'uid': uid,
      'entry': {
        'x': entryX,
        'y': entryY,
      }, // (เผื่อใช้ในอนาคต: คำนวณระยะทางจากทางเข้า)
      'holdSeconds': holdSeconds,
    });

    // แปลงข้อมูลที่ได้กลับมาเป็น Map
    final data = Map<String, dynamic>.from(res.data);

    // ถ้าผลลัพธ์บอกว่าไม่สำเร็จ (เช่น ไม่มีช่องว่าง) ให้คืนค่า null
    if (data['ok'] != true) return null;

    // แปลงเวลาหมดอายุจากรูปแบบ Timestamp เป็น DateTime
    DateTime? exp;
    final expRaw = data['hold_expires_at'];
    if (expRaw is Map && expRaw.containsKey('_seconds')) {
      exp = DateTime.fromMillisecondsSinceEpoch(
        (expRaw['_seconds'] as int) * 1000,
      );
    } else if (expRaw is String) {
      // รองรับกรณีที่บางทีส่งมาเป็น String ISO8601
      exp = DateTime.tryParse(expRaw);
    }

    // คืนค่าผลลัพธ์: ID ของเอกสาร, หมายเลขช่องจอด, และเวลาที่หมดเวลาจอง
    return (
      docId: data['docId'] as String,
      id: (data['id'] as num).toInt(),
      holdExpiresAt: exp,
    );
  }
}
