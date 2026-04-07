import 'package:logger/logger.dart';

/// Ring buffer for last N log lines for diagnostics screen.
class LogBuffer {
  LogBuffer._(this._capacity);
  static final LogBuffer instance = LogBuffer._(200);

  final int _capacity;
  final List<String> _lines = <String>[];
  String? lastError;

  void add(String line) {
    _lines.add(line);
    if (_lines.length > _capacity) {
      _lines.removeRange(0, _lines.length - _capacity);
    }
  }

  List<String> takeLast(int n) {
    if (_lines.length <= n) return List.unmodifiable(_lines);
    return List.unmodifiable(_lines.sublist(_lines.length - n));
  }
}

/// Logger output that writes to [LogBuffer] while still printing to console.
class MemoryLogOutput extends LogOutput {
  MemoryLogOutput(this.buffer);
  final LogBuffer buffer;

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      buffer.add(line);
    }
  }
}
