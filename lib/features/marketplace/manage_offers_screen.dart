import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/marketplace_service.dart';

class ManageOffersScreen extends ConsumerStatefulWidget {
  const ManageOffersScreen({super.key});
  @override
  ConsumerState<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends ConsumerState<ManageOffersScreen> {
  bool _loading = false;
  String? _error;
  List<MarketplaceOffer> _rows = const [];

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _rows = await ref
          .read(marketplaceServiceProvider)
          .offersForMyPostedLoads();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('No offers yet'))
                : ListView.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final o = _rows[i];
                      return ListTile(
                        leading: const Icon(Icons.handshake_outlined),
                        title: Text(
                          'Offer: \$${(o.bidCents / 100).toStringAsFixed(0)}',
                        ),
                        subtitle: Text(
                          'Status: ${o.status} • At: ${o.createdAt.toLocal()}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: o.status == 'pending'
                                  ? () async {
                                      await ref
                                          .read(marketplaceServiceProvider)
                                          .updateOfferStatus(
                                            offerId: o.id,
                                            status: 'accepted',
                                          );
                                      await _refresh();
                                    }
                                  : null,
                              child: const Text('Accept'),
                            ),
                            TextButton(
                              onPressed: o.status == 'pending'
                                  ? () async {
                                      await ref
                                          .read(marketplaceServiceProvider)
                                          .updateOfferStatus(
                                            offerId: o.id,
                                            status: 'rejected',
                                          );
                                      await _refresh();
                                    }
                                  : null,
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
