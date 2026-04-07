import 'package:local_notifier/local_notifier.dart';

class DashboardNotifications {
  static Future<void> initialize() async {
    // LocalNotifier 0.1.6+ uses setup() instead of initialize()
    try {
      await localNotifier.setup(appName: 'TruckerCore');
    } catch (e) {
      // Handle initialization errors gracefully in desktop contexts
      // ignore: avoid_print
      print('LocalNotifier setup failed: $e');
    }
  }

  static Future<void> showMaintenanceDue(String vehicle, int days) async {
    try {
      final notification = LocalNotification(
        title: 'Maintenance Alert',
        body: '$vehicle maintenance due in $days days',
        actions: [
          LocalNotificationAction(text: 'View Details'),
          LocalNotificationAction(text: 'Dismiss'),
        ],
      );
      await notification.show();
    } catch (_) {}
  }

  static Future<void> showLowFuelEfficiency(String vehicle, double mpg) async {
    try {
      final notification = LocalNotification(
        title: 'Fuel Alert',
        body: '$vehicle fuel efficiency below target: ${mpg.toStringAsFixed(1)} MPG',
      );
      await notification.show();
    } catch (_) {}
  }
}
