import '../services/supa_client.dart';

class EntitlementsService {
  final SupaClient client;
  final String accountId; // org or user id (store on login)
  EntitlementsService(this.client, this.accountId);

  Future<Set<String>> fetch() async {
    final res = await client.getJson(
      '/rest/v1/entitlements?select=feature,enabled&account_id=eq.$accountId',
    );
    final list = (res['data'] ?? res) as List;
    return list
        .where((e) => (e as Map)['enabled'] == true)
        .map<String>((e) => (e as Map)['feature'] as String)
        .toSet();
  }

  Future<String?> plan() async {
    final res = await client.getJson(
      '/rest/v1/subscriptions?select=plan,status&account_id=eq.$accountId&limit=1',
    );
    final list = (res['data'] ?? res) as List;
    if (list.isEmpty) return 'free';
    return (list.first as Map)['plan'] as String;
  }
}
