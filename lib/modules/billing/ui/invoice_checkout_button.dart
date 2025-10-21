import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing_service.dart';

class InvoiceCheckoutButton extends StatefulWidget {
  final List<Map<String,dynamic>> items;
  const InvoiceCheckoutButton({super.key, required this.items});
  @override State<InvoiceCheckoutButton> createState()=>_InvoiceCheckoutButtonState();
}
class _InvoiceCheckoutButtonState extends State<InvoiceCheckoutButton>{
  bool loading=false;

  Future<void> _go() async {
    setState(()=>loading=true);
    try{
      final s = Supabase.instance.client;
      final orgId = s.auth.currentUser!.appMetadata['app_org_id'] as String;
      final billing = BillingService(s);
      final invoiceId = await billing.createInvoice(orgId: orgId, items: widget.items);
      final itemsForStripe = widget.items.map((i)=>{'name': i['description'], 'quantity': i['qty'], 'amount': i['unit_price_cents']}).toList();
      final checkoutUrl = await billing.startCheckout(
        invoiceId: invoiceId, items: itemsForStripe,
        successUrl: 'https://yourapp.example/success',
        cancelUrl: 'https://yourapp.example/cancel',
      );
      await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Stripe Checkout…'))); }
    } finally { if(mounted) setState(()=>loading=false); }
  }

  @override Widget build(BuildContext ctx){
    return FilledButton(onPressed: loading?null:_go, child: loading?const CircularProgressIndicator():const Text('Pay Invoice'));
  }
}
