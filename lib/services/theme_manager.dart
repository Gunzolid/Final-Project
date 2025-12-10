import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper Class สำหรับจัดการ Theme (Dark/Light Mode)
/// ช่วยให้ค่าที่ผู้ใช้เลือกถูกบันทึกไว้และโหลดกลับมาใช้ใหม่เมื่อเปิดแอป
class ThemeManager {
  static const _prefsKey = 'theme_mode'; // ชื่อ Key ที่ใช้บันทึกในเครื่อง
  static SharedPreferences? _prefs;

  // ตัวแปร Notifier เพื่อบอกให้ Widget อื่นๆ รู้ว่า Theme เปลี่ยนแล้ว
  static final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  /// Getter สำหรับให้ Widget อื่นเรียกไปใช้ (เช่นใน main.dart)
  static ValueNotifier<ThemeMode> get themeNotifier => _themeNotifier;

  /// ฟังก์ชันเริ่มต้น (โหลดค่าที่บันทึกไว้)
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _prefs!.getString(_prefsKey);
    if (stored == null) return; // ถ้าไม่เคยบันทึก ให้ใช้ค่า Default (System)

    try {
      // แปลง String กลับเป็น Enum ThemeMode
      final restored = ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
      );
      _themeNotifier.value = restored;
    } catch (_) {
      // ถ้าข้อมูลเสียหาย ให้ข้ามไปใช้ค่า Default
    }
  }

  /// ฟังก์ชันเปลี่ยน Theme และบันทึกค่าลงเครื่องทันที
  static Future<void> updateTheme(ThemeMode mode) async {
    _themeNotifier.value = mode; // แจ้งเตือน UI ให้เปลี่ยนสี
    await _prefs?.setString(_prefsKey, mode.name); // บันทึกลง Storage
  }
}

/// ประกาศตัวแปร Global เพื่อให้ไฟล์อื่นเรียกใช้ได้ง่ายๆ (Backward Compatibility)
final ValueNotifier<ThemeMode> themeNotifier = ThemeManager.themeNotifier;
