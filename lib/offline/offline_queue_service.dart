import 'dart:async';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../transport/api_client.dart';
import '../utils/hash.dart';
import 'queue_operation.dart';

typedef ReplayResult = ({bool success, bool duplicate, int status, String? error});

class OfflineQueueService {
  static const _boxName = 'offline_queue_v1';
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  late final Box<QueueOperation> _box;
  Timer? _ticker;
  bool _busy = false;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(41)) Hive.registerAdapter(OpTypeAdapter());
    if (!Hive.isAdapterRegistered(42)) Hive.registerAdapter(QueueOperationAdapter());
    _box = await Hive.openBox<QueueOperation>(_boxName);
    _startTicker();
  }

  Future<QueueOperation> enqueue({
    required OpType type,
    required Map<String, dynamic> payload,
    required String serverTarget, // "rpc:book_load" or "POST:/api/positions"
  }) async {
    final id = const Uuid().v4();
    final key = makeDedupeKey(
      serverTarget: serverTarget,
      type: type.name,
      payload: payload,
    );

    // Prevent local dupes (fix: avoid null cast in firstWhere)
    QueueOperation? existing;
    for (final op in _box.values) {
      if (op.dedupeKey == key) {
        existing = op;
        break;
      }
    }
    if (existing != null) return existing;

    final op = QueueOperation(
      id: id,
      type: type,
      payload: payload,
      dedupeKey: key,
      createdAt: DateTime.now(),
      serverTarget: serverTarget,
    );

    await _box.put(id, op);
    return op;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => replayPending());
  }

  Future<void> replayPending() async {
    if (_busy) return;
    _busy = true;
    try {
      final api = ApiClient();
      final ops = _box.values.where((o) => o.attempts < 20).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final op in ops) {
        // connectivity check (cheap)
        if (!await api.hasNetwork()) break;

        // backoff: 2^attempts with jitter, cap at 5 minutes
        final backoffSecs = min(pow(2, op.attempts).toInt(), 300);
        final ageSecs = DateTime.now().difference(op.createdAt).inSeconds;
        if (op.attempts > 0 && ageSecs < backoffSecs) continue;

        final res = await _replayOne(api, op);
        if (res.success || res.duplicate) {
          await _box.delete(op.id); // done
        } else {
          op.attempts += 1;
          await op.save();
        }
      }
    } finally {
      _busy = false;
    }
  }

  Future<ReplayResult> _replayOne(ApiClient api, QueueOperation op) async {
    try {
      return await api.dispatchOp(op);
    } catch (e) {
      return (success: false, duplicate: false, status: 0, error: e.toString());
    }
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    await _box.close();
  }
}
