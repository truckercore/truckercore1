import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RunbookLink extends StatelessWidget {
  final String title;
  final String url;
  final String tooltip;
  const RunbookLink({super.key, required this.title, required this.url, required this.tooltip});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        icon: const Icon(Icons.menu_book_outlined, size: 18),
        label: Text(title),
        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    );
  }
}
