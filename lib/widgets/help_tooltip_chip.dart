// Tooltip chip that fetches help title/body from help_articles by key
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HelpTooltipChip extends StatefulWidget {
  final String helpKey;
  final String label;
  const HelpTooltipChip({super.key, required this.helpKey, required this.label});

  @override
  State<HelpTooltipChip> createState() => _HelpTooltipChipState();
}

class _HelpTooltipChipState extends State<HelpTooltipChip> {
  String? _title;
  String? _body;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final res = await c
        .from('help_articles')
        .select('title,body')
        .eq('key', widget.helpKey)
        .maybeSingle();
    if (mounted && res != null) {
      setState(() {
        _title = res['title'] as String?;
        _body = res['body'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _title ?? widget.label;
    final body = _body ?? 'More info coming soon.';
    return Tooltip(
      message: '$title\n\n$body',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      child: Chip(
        avatar: const Icon(Icons.help_outline, size: 16),
        label: Text(widget.label),
      ),
    );
  }
}
