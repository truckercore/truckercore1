import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseBreakdownChart extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;

  const ExpenseBreakdownChart({super.key, required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock data; real app would fetch from service
    final data = {
      'Fuel': 3500.0,
      'Maintenance': 1200.0,
      'Insurance': 800.0,
      'Tolls': 450.0,
      'Other': 350.0,
    };

    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
    ];

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _PieChartPainter(data, colors),
            child: Container(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: data.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.key}: \$${item.value.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;

  _PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final total = data.values.fold<double>(0, (a, b) => a + b);
    var startAngle = -math.pi / 2;

    final entries = data.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final sweepAngle = total == 0 ? 0.0 : (value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Donut hole
    canvas.drawCircle(
      center,
      radius * 0.6,
      Paint()..color = const Color(0xFF12161B),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
