import '../services/supa_client.dart';

class RemoteConfig {
  final SupaClient client;
  final Map<String, dynamic> _cache = {};
  RemoteConfig(this.client);

  Future<void> refresh() async {
    final res = await client.getJson('/rest/v1/app_config?select=key,value');
    final list = (res['data'] ?? res) as List;
    _cache
      ..clear()
      ..addEntries(list.map((e) => MapEntry(e['key'] as String, e['value'])));
  }

  T get<T>(String key, T fallback) {
    final v = _cache[key];
    return (v is T) ? v : fallback;
  }
}
