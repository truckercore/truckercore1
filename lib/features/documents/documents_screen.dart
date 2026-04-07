import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'documents_service.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  DocumentType? _filter;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Load from Supabase when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      // Attempt auto-retry of queued/failed uploads before loading
      await ref.read(documentsProvider.notifier).retryAllQueued();
      await ref.read(documentsProvider.notifier).loadMyDocuments();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);
    final filtered = _filter == null
        ? docs
        : docs.where((d) => d.type == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
          IconButton(
            tooltip: 'Clear local list',
            icon: const Icon(Icons.clear_all),
            onPressed: () => ref.read(documentsProvider.notifier).clearAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Queue status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Queue:'),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Queued'),
                  onSelected: (_) => setState(() {
                    _filter = _filter;
                  }),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Uploading'),
                  onSelected: (_) => setState(() {
                    _filter = _filter;
                  }),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Uploaded'),
                  onSelected: (_) => setState(() {
                    _filter = _filter;
                  }),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Failed'),
                  onSelected: (_) => setState(() {
                    _filter = _filter;
                  }),
                ),
              ],
            ),
          ),
          // Filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == null,
                  onSelected: () => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'BOL',
                  selected: _filter == DocumentType.bol,
                  onSelected: () => setState(() => _filter = DocumentType.bol),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Receipt',
                  selected: _filter == DocumentType.receipt,
                  onSelected: () =>
                      setState(() => _filter = DocumentType.receipt),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Inspection',
                  selected: _filter == DocumentType.inspection,
                  onSelected: () =>
                      setState(() => _filter = DocumentType.inspection),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Invoice',
                  selected: _filter == DocumentType.invoice,
                  onSelected: () =>
                      setState(() => _filter = DocumentType.invoice),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('No documents yet. Tap + to add.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      final sizeKb = d.sizeBytes == null
                          ? '?'
                          : (d.sizeBytes! / 1024).toStringAsFixed(1);
                      final statusText = () {
                        switch (d.status) {
                          case UploadStatus.queued:
                            return 'Queued';
                          case UploadStatus.uploading:
                            return 'Uploading…';
                          case UploadStatus.uploaded:
                            return 'Uploaded';
                          case UploadStatus.failed:
                            return 'Failed';
                        }
                      }();
                      final statusColor = d.status == UploadStatus.uploaded
                          ? Colors.green
                          : d.status == UploadStatus.failed
                          ? Colors.red
                          : Colors.orange;
                      return ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(d.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${documentTypeLabel(d.type)} • ${d.pagesCount} page(s) • $sizeKb KB',
                            ),
                            Row(
                              children: [
                                Chip(
                                  label: Text(statusText),
                                  backgroundColor: statusColor.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (d.status == UploadStatus.queued)
                                  const Text(
                                    'Will upload when online',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                if (d.status == UploadStatus.failed)
                                  Text(
                                    d.error ?? 'Error',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                            if (d.status == UploadStatus.uploading)
                              const Padding(
                                padding: EdgeInsets.only(top: 6.0, right: 48),
                                child: LinearProgressIndicator(minHeight: 3),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            switch (v) {
                              case 'retry':
                                await ref
                                    .read(documentsProvider.notifier)
                                    .retryUpload(d.id);
                                break;
                              case 'delete':
                                ref
                                    .read(documentsProvider.notifier)
                                    .removeById(d.id);
                                break;
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (d.status == UploadStatus.failed ||
                                d.status == UploadStatus.queued)
                              const PopupMenuItem(
                                value: 'retry',
                                child: Text('Retry'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_documents_add',
        icon: const Icon(Icons.add),
        label: const Text('Add Documents'),
        onPressed: () async {
          final type = await _pickType(context);
          if (type == null) return;
          await ref.read(documentsProvider.notifier).pickAndAdd(type);
          await _refresh();
        },
      ),
    );
  }

  Future<DocumentType?> _pickType(BuildContext context) {
    return showModalBottomSheet<DocumentType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Select document type')),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('BOL'),
              onTap: () => Navigator.of(ctx).pop(DocumentType.bol),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('POD'),
              onTap: () => Navigator.of(ctx).pop(DocumentType.pod),
            ),
            ListTile(
              leading: const Icon(Icons.scale),
              title: const Text('Scale Ticket'),
              onTap: () => Navigator.of(ctx).pop(DocumentType.scaleTicket),
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Receipt'),
              onTap: () => Navigator.of(ctx).pop(DocumentType.receipt),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check),
              title: const Text('Inspection'),
              onTap: () => Navigator.of(ctx).pop(DocumentType.inspection),
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: const Text('Other'),
              onTap: () => Navigator.of(ctx).pop(DocumentType.other),
            ),
            ListTile(
              leading: const Icon(Icons.request_quote),
              title: const Text('Invoice'),
              onTap: () => Navigator.of(ctx).pop(DocumentType.invoice),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
