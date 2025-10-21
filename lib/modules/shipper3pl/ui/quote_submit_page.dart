import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../shipper_service.dart';

class QuoteSubmitPage extends StatefulWidget {
  final String tenderId;
  const QuoteSubmitPage({super.key, required this.tenderId});
  @override State<QuoteSubmitPage> createState()=>_QuoteSubmitPageState();
}

class _QuoteSubmitPageState extends State<QuoteSubmitPage>{
  final price = TextEditingController();
  bool loading=false;

  @override void dispose(){ price.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(()=>loading=true);
    try{
      final supa = Supabase.instance.client;
      final bidder = supa.auth.currentUser!.appMetadata['app_org_id'] as String;
      final id = await ShipperService(supa).submitQuote(TenderQuote(
        id:'new', tenderId: widget.tenderId, bidderOrgId: bidder,
        priceCents: ((double.tryParse(price.text) ?? 0) * 100).round(),
        currency: 'USD', status: 'proposed'
      ));
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quote submitted $id'))); Navigator.pop(context); }
    } finally { if(mounted) setState(()=>loading=false); }
  }

  @override Widget build(BuildContext ctx){
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Quote (3PL/Fleet)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:'Your Price (USD)')),
          const SizedBox(height:16),
          ElevatedButton(onPressed: loading?null:_submit, child: loading?const CircularProgressIndicator():const Text('Send Quote')),
        ]),
      ),
    );
  }
}
