import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  final List<AdaptiveNavigationItem> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? floatingActionButton;

  /// Determines whether the current platform should display the desktop layout.
  ///
  /// Web and desktop OS targets (Windows/macOS/Linux) opt into the wider
  /// NavigationRail experience, while Android and iOS stay on the compact
  /// bottom navigation pattern.
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

    if (isDesktop) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon ?? item.icon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onDestinationSelected,
        type: BottomNavigationBarType.fixed, // Ensure background color shows
        backgroundColor: Colors.grey[200], // Darker background
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[700],
        items: destinations
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
