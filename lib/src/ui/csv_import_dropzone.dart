import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class CsvImportDropzone extends StatefulWidget {
  const CsvImportDropzone({super.key});

  @override
  State<CsvImportDropzone> createState() => _CsvImportDropzoneState();
}

class _CsvImportDropzoneState extends State<CsvImportDropzone> {
  bool _dragging = false;
  String? _selectedPath;

  Future<void> _pickCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (!mounted) return;
    if (res != null && res.files.single.path != null) {
      setState(() => _selectedPath = res.files.single.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected: ${res.files.single.name}')),
      );
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final files = details.files;
    final csv = files.where((x) => x.path.toLowerCase().endsWith('.csv')).toList();
    if (!mounted) return;
    if (csv.isNotEmpty) {
      setState(() => _selectedPath = csv.first.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dropped: ${csv.first.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _dragging ? Colors.teal : Theme.of(context).dividerColor;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) => _handleDrop(details),
            child: DottedBorder(
              color: borderColor,
              strokeWidth: 2,
              dashPattern: const [6, 6],
              child: Container(
                height: 200,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.file_upload, size: 42),
                    const SizedBox(height: 8),
                    const Text('Drag & drop CSV here'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choose File'),
                      onPressed: _pickCsv,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedPath != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(_selectedPath!.split(Platform.pathSeparator).last),
                subtitle: Text(_selectedPath!),
                trailing: FilledButton(
                  onPressed: () {},
                  child: const Text('Continue'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DottedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final List<double> dashPattern;

  const DottedBorder({
    super.key,
    required this.child,
    required this.color,
    required this.strokeWidth,
    this.dashPattern = const [4, 4],
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(color, strokeWidth, dashPattern),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final List<double> dashPattern;

  _DottedBorderPainter(this.color, this.strokeWidth, this.dashPattern);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()..addRect(rect);
    final dashArray = dashPattern;
    final double dashOn = dashArray[0], dashOff = dashArray[1];
    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final next = distance + dashOn;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashOff;
      }
      distance = 0.0;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
