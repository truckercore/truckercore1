import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/state/phase3_flags.dart';

class ApiKeyItem {
  final String id;
  final String label;
  final DateTime createdAt;
  DateTime? lastUsedAt;
  bool revoked;
  final String masked; // ****abcd
  ApiKeyItem({
    required this.id,
    required this.label,
    required this.createdAt,
    this.lastUsedAt,
    this.revoked = false,
    required this.masked,
  });
}

class _KeyMem {
  final List<ApiKeyItem> keys = <ApiKeyItem>[];
  final Map<String, String> plainTokensOnce =
      <String, String>{}; // id->token (once)
}

final _keyMemStore = Provider<_KeyMem>((_) => _KeyMem());

class ApiKeysService {
  ApiKeysService(this._ref);
  final Ref _ref;

  String _randomToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    return List.generate(40, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<(ApiKeyItem, String)> createKey({required String label}) async {
    final flags = _ref.read(phase3FlagsProvider);
    // mock mode: generate token; store masked; return token once
    if (flags.mock) {
      final id =
          'key_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      final token = _randomToken();
      final masked = '****${token.substring(token.length - 4)}';
      final item = ApiKeyItem(
        id: id,
        label: label,
        createdAt: DateTime.now(),
        masked: masked,
      );
      _ref.read(_keyMemStore).keys.insert(0, item);
      _ref.read(_keyMemStore).plainTokensOnce[id] = token;
      return (item, token);
    }
    // live path to be implemented
    final id = 'key_demo_${DateTime.now().millisecondsSinceEpoch}';
    final token = _randomToken();
    final item = ApiKeyItem(
      id: id,
      label: label,
      createdAt: DateTime.now(),
      masked: '****${token.substring(token.length - 4)}',
    );
    _ref.read(_keyMemStore).keys.insert(0, item);
    _ref.read(_keyMemStore).plainTokensOnce[id] = token;
    return (item, token);
  }

  Future<List<ApiKeyItem>> listKeys() async {
    return List<ApiKeyItem>.from(_ref.read(_keyMemStore).keys);
  }

  Future<void> revoke(String id) async {
    final ks = _ref.read(_keyMemStore).keys;
    for (final k in ks) {
      if (k.id == id) {
        k.revoked = true;
        break;
      }
    }
  }

  Future<bool> validateExternalLoadPost({required String token}) async {
    // mock: token valid if it matches a non-revoked key token stored
    final mem = _ref.read(_keyMemStore);
    // tokens only visible once; after listing, we only compare masked? For mock simplicity, keep tokens in map
    for (final entry in mem.plainTokensOnce.entries) {
      final id = entry.key;
      final t = entry.value;
      if (t == token) {
        final item = mem.keys.firstWhere(
          (e) => e.id == id,
          orElse: () => ApiKeyItem(
            id: id,
            label: '',
            createdAt: DateTime.now(),
            masked: '',
          ),
        );
        if (item.revoked) return false;
        item.lastUsedAt = DateTime.now();
        return true;
      }
    }
    return false;
  }
}

final apiKeysServiceProvider = Provider<ApiKeysService>(
  (ref) => ApiKeysService(ref),
);
