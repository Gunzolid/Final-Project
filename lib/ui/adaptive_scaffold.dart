import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// =================================================================================
// ADAPTIVE SCAFFOLD: โครงหน้าจอที่ปรับเปลี่ยนได้ตามขนาด (Responsive)
// =================================================================================

/// คลาสเก็บข้อมูลเมนูนำทาง (ไอคอนและชื่อ)
class AdaptiveNavigationItem {
  const AdaptiveNavigationItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

/// วิดเจ็ตหลักที่จะเลือกแสดงผลระหว่าง BottomNavigationBar (มือถือ)
/// หรือ NavigationRail (แท็บเล็ต/เว็บ) โดยอัตโนมัติ
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<AdaptiveNavigationItem> destinations; // รายการเมนู
  final int currentIndex; // หน้าปัจจุบันที่เลือกอยู่
  final ValueChanged<int> onDestinationSelected; // ฟังก์ชันเมื่อกดเลือกเมนู
  final Widget? floatingActionButton;

  /// ฟังก์ชันตรวจสอบว่าควรใช้ Layout แบบ Desktop หรือไม่
  /// - ถ้าเป็น Web หรือ Desktop OS (Windows, MacOS, Linux) -> ใช้ Desktop Layout
  /// - ถ้าเป็น Android, iOS -> ใช้ Mobile Layout
  static bool useDesktopLayout(BuildContext context) {
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = useDesktopLayout(context);

    // =========================================================
    // DESKTOP / WEB LAYOUT: เมนูอยู่ด้านซ้าย (NavigationRail)
    // =========================================================
    if (isDesktop) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            // เมนูแนวตั้งด้านซ้าย
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations:
                  destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon ?? item.icon),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
            ),
            const VerticalDivider(width: 1), // เส้นแบ่งแนวตั้ง
            // เนื้อหาหลัก (ขยายให้เต็มพื้นที่ที่เหลือ)
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    // =========================================================
    // MOBILE LAYOUT: เมนูอยู่ด้านล่าง (BottomNavigationBar)
    // =========================================================
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onDestinationSelected,
        type: BottomNavigationBarType.fixed, // แบบ Fixed จะเห็นพื้นหลังชัดเจน
        backgroundColor: Colors.grey[200], // พื้นหลังสีเทาอ่อน
        selectedItemColor: Theme.of(context).primaryColor, // สีไอคอนที่เลือก
        unselectedItemColor: Colors.grey[700], // สีไอคอนปกติ
        items:
            destinations
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    activeIcon: Icon(item.selectedIcon ?? item.icon),
                    label: item.label,
                  ),
                )
                .toList(),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
