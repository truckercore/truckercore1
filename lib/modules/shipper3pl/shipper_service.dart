import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class ShipperService {
  final SupabaseClient _supabase;
  ShipperService(this._supabase);

  Future<String> createTender(Tender t) async {
    final res = await _supabase.from('tenders').insert(t.toInsert()).select('id').single();
    return res['id'] as String;
  }

  Future<List<Map<String, dynamic>>> listOpenTenders() async {
    return await _supabase.from('tenders').select().eq('status', 'open').order('created_at');
  }

  Future<String> submitQuote(TenderQuote q) async {
    final res = await _supabase.from('tender_quotes').insert(q.toInsert()).select('id').single();
    return res['id'] as String;
  }

  // New helper supporting idempotency keys and raw map payloads
  Future<String> submitQuoteMap(Map<String, dynamic> q, {String? idempotencyKey}) async {
    final payload = { ...q, if (idempotencyKey != null) 'idempotency_key': idempotencyKey };
    final res = await _supabase.from('tender_quotes')
        .insert(payload)
        .select('id').single();
    return res['id'] as String;
  }

  Future<void> acceptQuote({required String quoteId}) async {
    await _supabase.rpc('accept_tender_quote', params: {'p_quote_id': quoteId});
  }
}
