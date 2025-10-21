import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/config/app_config.dart';
import '../../common/services/supabase_client.dart';

// Types
enum DocumentType { bol, pod, scaleTicket, receipt, other, inspection, invoice }

String documentTypeLabel(DocumentType t) {
  switch (t) {
    case DocumentType.bol:
      return 'BOL';
    case DocumentType.pod:
      return 'POD';
    case DocumentType.scaleTicket:
      return 'Scale Ticket';
    case DocumentType.receipt:
      return 'Receipt';
    case DocumentType.other:
      return 'Other';
    case DocumentType.inspection:
      return 'Inspection';
    case DocumentType.invoice:
      return 'Invoice';
  }
}

enum UploadStatus { queued, uploading, uploaded, failed }

class DocumentItem {
  final String id;
  final String name;
  final int? sizeBytes; // bytes
  final int pagesCount;
  final DateTime createdAt;
  final DateTime? uploadedAt;
  final DocumentType type;
  final List<String> files; // local paths or bytes refs; for MVP store names
  final UploadStatus status;
  final String? error; // failure reason
  final int retryCount;
  final String? note;
  final String? remoteUrl; // public URL from Supabase Storage when uploaded
  final String? tripId;
  final String? loadId;

  const DocumentItem({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.pagesCount,
    required this.createdAt,
    required this.uploadedAt,
    required this.type,
    required this.files,
    required this.status,
    this.error,
    this.retryCount = 0,
    this.note,
    this.remoteUrl,
    this.tripId,
    this.loadId,
  });

  DocumentItem copyWith({
    String? id,
    String? name,
    int? sizeBytes,
    int? pagesCount,
    DateTime? createdAt,
    DateTime? uploadedAt,
    DocumentType? type,
    List<String>? files,
    UploadStatus? status,
    String? error,
    int? retryCount,
    String? note,
    String? remoteUrl,
    String? tripId,
    String? loadId,
  }) => DocumentItem(
    id: id ?? this.id,
    name: name ?? this.name,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    pagesCount: pagesCount ?? this.pagesCount,
    createdAt: createdAt ?? this.createdAt,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    type: type ?? this.type,
    files: files ?? this.files,
    status: status ?? this.status,
    error: error,
    retryCount: retryCount ?? this.retryCount,
    note: note ?? this.note,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    tripId: tripId ?? this.tripId,
    loadId: loadId ?? this.loadId,
  );
}

class DocumentsController extends StateNotifier<List<DocumentItem>> {
  DocumentsController(this._read) : super(const []);

  final Ref _read;

  Future<void> loadMyDocuments() async {
    // No-op load for now; documents are added locally via pickAndAdd.
    // You can implement backend fetching here when needed.
    return;
  }

  Future<void> pickAndAdd(
    DocumentType type, {
    String? loadId,
    String? tripId,
  }) async {
    // Ensure Supabase is initialized (url/key set). If not, fallback to local add.
    final cfg = _read.read(appConfigProvider);
    final isReady =
        cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
    final supabase = isReady ? _read.read(supabaseClientProvider) : null;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final now = DateTime.now();
    int counter = 0;

    final List<DocumentItem> uploaded = [];
    // offline flag was unused; rely on isReady directly

    for (final f in result.files) {
      // Simple duplicate detection: same filename and size within this session
      final dup = state.any((d) => d.name == f.name && d.sizeBytes == f.size);
      if (dup) {
        // Skip duplicate; in a full app, prompt to merge pages
        continue;
      }
      counter++;
      final id = '${now.microsecondsSinceEpoch}_$counter';
      final filename = f.name;
      final bytes = f.bytes; // available on web when withData: true
      final path =
          'guest/$id-$filename'; // you can change 'guest' to userId later

      String publicUrl = '';
      UploadStatus status = UploadStatus.queued;
      String? err;
      DateTime? uploadedAt;
      final int pages = 1;
      if (isReady && bytes != null && supabase != null) {
        try {
          status = UploadStatus.uploading;
          await supabase.storage
              .from('documents')
              .uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );
          final urlStr = supabase.storage
              .from('documents')
              .getPublicUrl(path)
              .toString();
          publicUrl = urlStr;
          status = UploadStatus.uploaded;
          uploadedAt = DateTime.now();
        } catch (e) {
          status = UploadStatus.failed;
          err = e.toString();
        }
      } else {
        status = UploadStatus.queued;
      }

      uploaded.add(
        DocumentItem(
          id: id,
          name: filename,
          sizeBytes: f.size,
          pagesCount: pages,
          createdAt: now,
          uploadedAt: uploadedAt,
          type: type,
          files: [filename],
          status: status,
          error: err,
          remoteUrl: publicUrl.isEmpty ? null : publicUrl,
          tripId: tripId,
          loadId: loadId,
        ),
      );
    }

    state = [...state, ...uploaded];
  }

  void removeById(String id) {
    state = state.where((d) => d.id != id).toList();
  }

  void clearAll() {
    state = const [];
  }

  Future<void> retryUpload(String id) async {
    final idx = state.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    final item = state[idx];
    final cfg = _read.read(appConfigProvider);
    final isReady =
        cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
    if (!isReady) {
      // still offline, keep queued
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx)
            item.copyWith(
              status: UploadStatus.queued,
              retryCount: item.retryCount + 1,
            )
          else
            state[i],
      ];
      return;
    }
    try {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx)
            item.copyWith(status: UploadStatus.uploading)
          else
            state[i],
      ];
      // Use Supabase client lazily only if needed; remove unused local path variable to satisfy lints
      _read.read(supabaseClientProvider);
      // final path = 'guest/${item.id}-${item.name}';
      // We don't have bytes persisted in this MVP; rely on existing remoteUrl or skip
      // In a production app we would persist raw bytes to local storage. Here we fail gracefully.
      if (item.remoteUrl != null) {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == idx)
              item.copyWith(
                status: UploadStatus.uploaded,
                uploadedAt: DateTime.now(),
              )
            else
              state[i],
        ];
        return;
      }
      // Without raw bytes, we cannot re-upload; mark failed with note.
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx)
            item.copyWith(
              status: UploadStatus.failed,
              error: 'No local bytes available to retry',
              retryCount: item.retryCount + 1,
            )
          else
            state[i],
      ];
    } catch (e) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx)
            item.copyWith(
              status: UploadStatus.failed,
              error: e.toString(),
              retryCount: item.retryCount + 1,
            )
          else
            state[i],
      ];
    }
  }

  // Simple auto-retry sweep to be called when connectivity is restored.
  Future<void> retryAllQueued() async {
    final queued = state
        .where(
          (d) =>
              d.status == UploadStatus.queued ||
              d.status == UploadStatus.failed,
        )
        .toList();
    for (final d in queued) {
      await retryUpload(d.id);
    }
  }
}

final documentsProvider =
    StateNotifierProvider<DocumentsController, List<DocumentItem>>((ref) {
      return DocumentsController(ref);
    });
