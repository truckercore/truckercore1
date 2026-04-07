// lib/widgets/announcement_banner.dart
import 'package:flutter/material.dart';

class AnnouncementBanner extends StatelessWidget {
  final String title;
  final String body;
  const AnnouncementBanner({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(body),
      ),
    );
  }
}
