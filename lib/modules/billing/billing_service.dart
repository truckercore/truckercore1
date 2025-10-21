import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillingService {
  final SupabaseClient s;
  BillingService(this.s);

  Future<String> createInvoice({
    required String orgId,
    required List<Map<String,dynamic>> items,
    String? idempotencyKey,
  }) async {
    final total = items.fold<int>(0, (sum, it) => sum + (it['qty'] as int) * (it['unit_price_cents'] as int));
    final inv = await s.from('invoices').insert({
      'org_id': orgId,
      'subtotal_cents': total,
      'total_cents': total,
      'status':'open',
      'idempotency_key': idempotencyKey,
    }).select('id').single();
    final invoiceId = inv['id'] as String;
    for(final it in items){
      await s.from('invoice_items').insert({
        'invoice_id': invoiceId,
        'description': it['description'],
        'qty': it['qty'],
        'unit_price_cents': it['unit_price_cents'],
      });
    }
    return invoiceId;
  }

  Future<Uri> startCheckout({
    required String invoiceId,
    required List<Map<String,dynamic>> items, // {name, quantity, amount}
    required String successUrl,
    required String cancelUrl,
  }) async {
    // Use Supabase Edge Functions client API (v2+)
    final jwt = s.auth.currentSession?.accessToken;
    final response = await s.functions.invoke(
      'invoice_checkout',
      body: {
        'invoiceId': invoiceId,
        'lineItems': items,
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
      },
      headers: jwt == null ? null : {'Authorization': 'Bearer $jwt'},
    );
    if (response.status >= 300) {
      throw Exception(response.data);
    }
    final dynamic raw = response.data;
    final Map<String, dynamic> data = raw is String ? jsonDecode(raw) as Map<String, dynamic> : (raw as Map<String, dynamic>);
    return Uri.parse(data['url'] as String);
  }
}
