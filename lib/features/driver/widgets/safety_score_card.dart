import 'package:flutter/material.dart';
import '../../driver/models/safety_event.dart';

class SafetyScoreCard extends StatelessWidget {
  final DrivingSafetyScore score;

  const SafetyScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Safety Score',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildScoreBadge(score.overallScore),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildScoreCircle(
                    'Speed',
                    score.speedingScore,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildScoreCircle(
                    'Braking',
                    score.brakingScore,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildScoreCircle(
                    'Acceleration',
                    score.accelerationScore,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildScoreCircle(
                    'Cornering',
                    score.corneringScore,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Events'),
                  Text(
                    '${score.totalEvents}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBadge(double score) {
    Color color;
    if (score >= 90) {
      color = Colors.green;
    } else if (score >= 75) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        score.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildScoreCircle(String label, double score, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  score.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
