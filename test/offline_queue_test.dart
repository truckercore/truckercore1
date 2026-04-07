import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckercore1/features/tracking/offline_queue.dart';
import 'package:truckercore1/features/tracking/tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsQueue', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists across instances and removes through seq', () async {
      final q1 = SharedPrefsQueue(maxEntries: 100);
      await q1.init();
      // Enqueue 3 points for device A and 2 for device B
      await q1.enqueueAll([
        GpsPoint(deviceId: 'A', seq: 1, ts: DateTime.utc(2025), lat: 1, lng: 1),
        GpsPoint(deviceId: 'A', seq: 2, ts: DateTime.utc(2025,1,1,0,0,1), lat: 1, lng: 1.1),
        GpsPoint(deviceId: 'A', seq: 3, ts: DateTime.utc(2025,1,1,0,0,2), lat: 1, lng: 1.2),
        GpsPoint(deviceId: 'B', seq: 1, ts: DateTime.utc(2025), lat: 2, lng: 2),
        GpsPoint(deviceId: 'B', seq: 2, ts: DateTime.utc(2025,1,1,0,0,1), lat: 2, lng: 2.1),
      ]);
      expect(await q1.size(), 5);

      // New instance should read the same buffer
      final q2 = SharedPrefsQueue(maxEntries: 100);
      await q2.init();
      expect(await q2.size(), 5);
      final peek = await q2.peek(10);
      expect(peek.length, 5);

      // Remove through seq for device A (<=2)
      await q2.removeThroughSeq('A', 2);
      expect(await q2.size(), 3);
      final left = await q2.peek(10);
      // Remaining should include A:3 and B:1..2
      expect(left.where((e) => e.deviceId == 'A').length, 1);
      expect(left.where((e) => e.deviceId == 'B').length, 2);
    });
  });

  group('SeqStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('reads and writes last seq per device', () async {
      final s = SeqStore();
      expect(await s.read('devX'), 0);
      await s.write('devX', 42);
      expect(await s.read('devX'), 42);
      await s.write('devX', 43);
      expect(await s.read('devX'), 43);
    });
  });
}
