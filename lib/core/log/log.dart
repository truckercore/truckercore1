enum LogTag { boot, supabase, repo, network, ui, auth }

String friendlyError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('timeout') || s.contains('socket')) return 'Network is slow—try again.';
  if (s.contains('401') || s.contains('forbidden') || s.contains('auth')) return 'Session expired—please sign in again.';
  if (s.contains('rate') && s.contains('limit')) return 'Too many requests—try again in a moment.';
  return 'Something went wrong—please try again.';
}
