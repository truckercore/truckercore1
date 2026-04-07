import 'package:flutter/material.dart';

class MappingGuideCard extends StatelessWidget {
  const MappingGuideCard({super.key});
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Webhook Mapping',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '1) Create a webhook with your shipper portal pointing to /functions/v1/visibility_ingest',
            ),
            Text('2) Provide your secret; we verify and store raw events'),
            Text(
              '3) Map provider fields → our milestone codes (PICKED_UP, AT_STOP, DELIVERED)',
            ),
          ],
        ),
      ),
    );
  }
}
