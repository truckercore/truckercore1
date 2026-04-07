import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:tray_manager/tray_manager.dart';

class SystemTrayService with TrayListener {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    final tray = SystemTrayService();
    await tray._init();
    _initialized = true;
  }

  Future<void> _init() async {
    TrayManager.instance.addListener(this);

    String iconPath;
    if (Platform.isWindows) {
      iconPath = 'assets/icons/tray/tray_icon.ico';
    } else if (Platform.isMacOS) {
      iconPath = 'assets/icons/tray/tray_icon.png';
    } else {
      iconPath = 'assets/icons/tray/tray_icon.png';
    }

    await TrayManager.instance.setIcon(iconPath);
    await TrayManager.instance.setToolTip('TruckerCore Desktop');

    // Context menu temporarily disabled to maintain analyzer compatibility across versions.
    // await TrayManager.instance.setContextMenu(
    //   Menu(items: [
    //     MenuItem(key: 'show', label: 'Show'),
    //     MenuItem(key: 'quick_import', label: 'Import CSV'),
    //     MenuItem(key: 'quit', label: 'Quit'),
    //   ]),
    // );
  }

  @override
  void onTrayIconMouseDown() async {
    await TrayManager.instance.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        appWindow.show();
        break;
      case 'quick_import':
        // TODO: navigate to CSV importer route
        appWindow.show();
        break;
      case 'quit':
        appWindow.close();
        break;
      default:
    }
  }
}
