import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'upsell_card_props.dart';

class UpsellCard extends StatefulWidget {
  final UpsellCardProps props;
  const UpsellCard({super.key, required this.props});

  @override
  State<UpsellCard> createState() => _UpsellCardState();
}

class _UpsellCardState extends State<UpsellCard> {
  bool busy = false;

  Future<void> _upgrade() async {
    if (busy) return;
    setState(() => busy = true);
    final requestId = _uuid();
    widget.props.logEvt({
      't': 'upsell_click',
      'feature': widget.props.item.key,
      'tier': widget.props.item.tier,
      'org_id': widget.props.orgId,
      'requestId': requestId,
      'variant': widget.props.item.variant,
    });
    try {
      final r = await http.post(
        Uri.parse('/functions/v1/create_checkout'),
        headers: {
          'Content-Type': 'application/json',
          'X-Request-Id': requestId,
          'Authorization': 'Bearer ${widget.props.token}',
        },
        body: jsonEncode({'priceId': widget.props.item.priceId, 'orgId': widget.props.orgId}),
      );
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['status'] != 'ok' || j['url'] == null) {
        throw Exception(j['message'] ?? 'checkout failed');
      }
      widget.props.logEvt({'t': 'checkout_open', 'priceId': widget.props.item.priceId, 'requestId': requestId, 'variant': widget.props.item.variant});
      final url = j['url'] as String;
      if (widget.props.onCheckoutUrl != null) {
        await widget.props.onCheckoutUrl!(url);
      } else {
        // In Flutter, open the browser; leave actual navigation to app integration.
      }
      if (widget.props.onAfterSuccess != null) {
        await widget.props.onAfterSuccess!();
      }
    } catch (e) {
      widget.props.logEvt({'t': 'checkout_error', 'priceId': widget.props.item.priceId, 'requestId': requestId, 'message': e.toString(), 'variant': widget.props.item.variant});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout error: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.props.disabled || !widget.props.entLoaded || busy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.props.item.headline, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (widget.props.item.blurb != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.props.item.blurb!),
            ),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton(
              onPressed: isDisabled ? null : _upgrade,
              child: Text(busy ? 'Processing…' : 'Upgrade'),
            ),
            const SizedBox(width: 8),
            if (widget.props.item.runbookUrl != null)
              TextButton(
                onPressed: () {
                  // open runbook URL in browser (integrate in app)
                },
                child: const Text('Learn more'),
              ),
          ]),
        ]),
      ),
    );
  }

  String _uuid() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
