// lib/pages/forum.dart
import 'package:flutter/material.dart';

class ForumPage extends StatelessWidget {
  final List<Map<String, String>> posts = const [
    {'author': 'DriverA', 'body': 'Best route for Dallas-Houston?'},
    {'author': 'DriverB', 'body': 'Avoid I-45 construction this week.'}
  ];

  const ForumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Forum')),
      body: ListView(
        children: posts
            .map((p) => ListTile(
                  title: Text(p['author'] ?? ''),
                  subtitle: Text(p['body'] ?? ''),
                ))
            .toList(),
      ),
    );
  }
}
