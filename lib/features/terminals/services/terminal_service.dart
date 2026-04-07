import 'package:flutter_riverpod/flutter_riverpod.dart';

class Terminal {
  final String id;
  final String name;
  final String city;
  const Terminal({required this.id, required this.name, required this.city});
}

// Mock terminals; replace with Supabase later
final terminalsProvider = Provider<List<Terminal>>((ref) {
  return const [
    Terminal(id: 'TX-DAL', name: 'Dallas Terminal', city: 'Dallas, TX'),
    Terminal(id: 'CO-DEN', name: 'Denver Terminal', city: 'Denver, CO'),
    Terminal(id: 'TN-BNA', name: 'Nashville Terminal', city: 'Nashville, TN'),
  ];
});

// Selected terminal state (null = All)
final selectedTerminalIdProvider = StateProvider<String?>((ref) => null);
