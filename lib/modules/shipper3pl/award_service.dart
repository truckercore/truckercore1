import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/idempotency/idem.dart';

class AwardService {
  final SupabaseClient s;
  AwardService(this.s);

  Future<String> awardAndInvoice({required String quoteId}) async {
    final idem = generateIdempotencyKey(prefix: 'award');
    final res = await s.rpc('award_quote_and_invoice', params: {
      'p_quote_id': quoteId,
      'p_idempotency_key': idem,
    });
    return res as String;
  }
}
