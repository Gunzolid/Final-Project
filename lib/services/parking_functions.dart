// ในไฟล์ lib/services/parking_functions.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingFunctions {
  static final _functions = FirebaseFunctions.instance;

  static Future<({String docId, int id, DateTime? holdExpiresAt})?> recommend({
    int entryX = 0,
    int entryY = 0,
    int holdSeconds = 900,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    // VVV แก้ไขบรรทัดนี้ VVV
    final callable = _functions.httpsCallable('recommendAndHold');
    final res = await callable.call({
      'uid': uid,
      'entry': {'x': entryX, 'y': entryY},
      'holdSeconds': holdSeconds,
    });
    // ... (โค้ดส่วนที่เหลือเหมือนเดิม) ...
    final data = Map<String, dynamic>.from(res.data);
    if (data['ok'] != true) return null;

    DateTime? exp;
    final expRaw = data['hold_expires_at'];
    if (expRaw is Map && expRaw.containsKey('_seconds')) {
      exp = DateTime.fromMillisecondsSinceEpoch(
        (expRaw['_seconds'] as int) * 1000,
      );
    }

    return (
      docId: data['docId'] as String,
      id: (data['id'] as num).toInt(),
      holdExpiresAt: exp,
    );
  }
}
