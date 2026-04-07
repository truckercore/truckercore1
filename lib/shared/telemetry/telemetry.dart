import 'dart:developer' as dev;

class Telemetry {
  static void event(String name, Map<String, dynamic> props) {
    // Minimal client-side telemetry stub. Replace with your analytics sink.
    dev.log('[telemetry] $name ${props.toString()}');
  }
}
