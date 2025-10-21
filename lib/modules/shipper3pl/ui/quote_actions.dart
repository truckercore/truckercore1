import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../award_service.dart';

class QuoteActions extends StatefulWidget {
  final String quoteId;
  const QuoteActions({super.key, required this.quoteId});
  @override State<QuoteActions> createState()=>_QuoteActionsState();
}

class _QuoteActionsState extends State<QuoteActions>{
  bool loading=false;

  Future<void> _award() async {
    setState(()=>loading=true);
    try{
      final s = Supabase.instance.client;
      final svc = AwardService(s);
      final invoiceId = await svc.awardAndInvoice(quoteId: widget.quoteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quote awarded. Invoice $invoiceId created.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')));
      }
    } finally { if (mounted) setState(()=>loading=false); }
  }

  @override Widget build(BuildContext c){
    return FilledButton.icon(
      onPressed: loading?null:_award,
      icon: const Icon(Icons.verified),
      label: loading
        ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
        : const Text('Award & Invoice'),
    );
  }
}
