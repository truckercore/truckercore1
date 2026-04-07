import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RevenueChart extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;

  const RevenueChart({super.key, required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = _generateMockData();
    return CustomPaint(
      painter: _LineChartPainter(data, Colors.green),
      child: Container(),
    );
  }

  List<double> _generateMockData() {
    return List.generate(7, (i) => 5000 + (i * 500) + (i % 2 == 0 ? 1000 : 0));
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _LineChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs() < 0.0001 ? 1.0 : (maxValue - minValue);

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
