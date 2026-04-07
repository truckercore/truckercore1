// lib/services/billing.dart
// Helpers for Stripe billing via Supabase Edge Functions (supabase_flutter v2)

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> startCheckout(String priceId) async {
  // Use Supabase Functions invoke; it automatically includes the user session JWT
  final resp = await Supabase.instance.client.functions.invoke(
    'create_checkout_session',
    body: {'price_id': priceId},
  );
  if (resp.status < 200 || resp.status >= 300) {
    throw Exception('Checkout failed: ${resp.data}');
  }
  // Expecting { url: "..." }
  final data = resp.data is Map ? (resp.data as Map) : {};
  final urlStr = data['url']?.toString();
  if (urlStr == null) {
    throw Exception('Checkout failed: missing redirect URL');
  }
  final uri = Uri.parse(urlStr);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<Map<String, dynamic>> getBillingProfile() async {
  final resp = await Supabase.instance.client.functions.invoke('billing_overview');
  if (resp.status < 200 || resp.status >= 300) {
    throw Exception('billing_overview failed: ${resp.data}');
  }
  final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
  return data;
}

Future<void> openBillingPortal() async {
  final resp = await Supabase.instance.client.functions.invoke('create_billing_portal');
  if (resp.status < 200 || resp.status >= 300) {
    throw Exception('create_billing_portal failed: ${resp.data}');
  }
  final data = resp.data is Map ? (resp.data as Map) : {};
  final urlStr = data['url']?.toString();
  if (urlStr == null) {
    throw Exception('create_billing_portal failed: missing redirect URL');
  }
  final uri = Uri.parse(urlStr);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
