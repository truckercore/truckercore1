import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser!;
    final checkoutUrl = Uri.parse(
      'https://app.truckercore.com/api/billing/checkout?user_id=${user.id}&tier=premium',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(checkoutUrl)),
        shouldOverrideUrlLoading: (ctrl, nav) async {
          final url = nav.request.url.toString();
          if (url.contains('/billing/success')) {
            if (context.mounted) Navigator.of(context).pop(true);
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
