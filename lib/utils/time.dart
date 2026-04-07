class TimeFmt {
  // Format like 3:05 PM
  static String hm(DateTime t) {
    final lt = t.toLocal();
    final h12 = lt.hour % 12 == 0 ? 12 : lt.hour % 12;
    final m = lt.minute.toString().padLeft(2, '0');
    final ampm = lt.hour >= 12 ? 'PM' : 'AM';
    return '$h12:$m $ampm';
    
  }

  // Very small relative formatter: "x min ago", "y h ago", or "Just now"
  static String relative(DateTime t) {
    final diff = DateTime.now().difference(t.toLocal());
    if (diff.inSeconds < 30) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m == 1 ? '1 min ago' : '$m min ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? '1 h ago' : '$h h ago';
    }
    final d = diff.inDays;
    return d == 1 ? '1 day ago' : '$d days ago';
  }
}
