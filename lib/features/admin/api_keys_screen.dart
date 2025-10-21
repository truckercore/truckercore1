import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/widgets/app_background.dart';
import '../api_keys/api_keys_service.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});
  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  final _label = TextEditingController(text: 'Server Integration');
  String? _lastToken;
  bool _busy = false;
  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(apiKeysServiceProvider)
          .createKey(label: _label.text.trim());
      if (!mounted) {
        return;
      }
      final token = r.$2;
      setState(() => _lastToken = token);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key created. Token visible once below.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revoke(String id) async {
    await ref.read(apiKeysServiceProvider).revoke(id);
    setState(() => {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Keys')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Key',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _label,
                            decoration: const InputDecoration(
                              labelText: 'Label',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _create,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.vpn_key),
                          label: const Text('Create'),
                        ),
                      ],
                    ),
                    if (_lastToken != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(
                          'Token (copy now): \n$_lastToken',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keys',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder(
                      future: ref.read(apiKeysServiceProvider).listKeys(),
                      builder: (context, snap) {
                        final items = snap.data ?? const <ApiKeyItem>[];
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (items.isEmpty) {
                          return const ListTile(title: Text('No keys yet.'));
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final k = items[i];
                            return ListTile(
                              leading: const Icon(Icons.vpn_key),
                              title: Text(k.label),
                              subtitle: Text(
                                'Created: ${k.createdAt.toLocal()}\nMasked: ${k.masked}  •  Revoked: ${k.revoked}  •  Last used: ${k.lastUsedAt?.toLocal() ?? '—'}',
                              ),
                              trailing: k.revoked
                                  ? const SizedBox.shrink()
                                  : TextButton(
                                      onPressed: () => _revoke(k.id),
                                      child: const Text('Revoke'),
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
