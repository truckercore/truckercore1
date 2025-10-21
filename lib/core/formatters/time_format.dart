import 'package:intl/intl.dart';

String fmtDateTime(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final df = DateFormat.yMMMd().add_jm();
  return df.format(local);
}

String timeAgoShort(DateTime? dt) {
  if (dt == null) return 'never';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
