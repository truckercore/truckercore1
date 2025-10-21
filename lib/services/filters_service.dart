import '../models/saved_filter.dart';
import '../services/supa_client.dart';

class FiltersService {
  final SupaClient client;
  FiltersService(this.client);

  Future<List<SavedFilter>> list(String scope, String userId) async {
    final res = await client.getJson(
      '/rest/v1/saved_filters?select=*&scope=eq.$scope&user_id=eq.$userId&order=created_at.desc',
    );
    final data = (res['data'] ?? res) as List;
    return data
        .map((e) => SavedFilter.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SavedFilter> save(
    String scope,
    String userId,
    String name,
    Map<String, dynamic> json,
  ) async {
    await client.postJson('/rest/v1/saved_filters', {
      'user_id': userId,
      'scope': scope,
      'name': name,
      'json': json,
    });
    final all = await list(scope, userId);
    return all.first;
  }
}
