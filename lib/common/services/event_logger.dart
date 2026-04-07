import 'package:supabase_flutter/supabase_flutter.dart';

class EventLogger {
  final SupabaseClient _c;
  const EventLogger(this._c);

  Future<void> log(String eventType, Map<String, dynamic> payload) async {
    try {
      await _c.from('dispatch_events').insert({
        'event_type': eventType,
        'details': payload,
      });
    } catch (_) {
      // best effort only
    }
  }
}
