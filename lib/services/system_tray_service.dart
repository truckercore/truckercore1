// lib/services/system_tray_service.dart
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:tray_manager/tray_manager.dart';

class SystemTrayService with TrayListener {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    final svc = SystemTrayService();
    await svc._init();
    _initialized = true;
  }

  Future<void> _init() async {
    TrayManager.instance.addListener(this);

    final iconPath = Platform.isWindows
        ? 'assets/icons/tray/tray_icon.ico'
        : 'assets/icons/tray/tray_icon.png';

    await TrayManager.instance.setIcon(iconPath);
    await TrayManager.instance.setToolTip('TruckerCore Desktop');

    // Context menu temporarily disabled to maintain analyzer compatibility across versions.
    // await TrayManager.instance.setContextMenu(
    //   Menu(items: [
    //     MenuItem(key: 'show', label: 'Show'),
    //     MenuItem(key: 'import_csv', label: 'Import CSV'),
    //     MenuItem(key: 'quit', label: 'Quit'),
    //   ]),
    // );
  }

  @override
  void onTrayIconMouseDown() {
    TrayManager.instance.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        appWindow.show();
        break;
      case 'import_csv':
        appWindow.show();
        // TODO: route to CSV Import
        break;
      case 'quit':
        appWindow.close();
        break;
    }
  }
}
