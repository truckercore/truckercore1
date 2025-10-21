import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../offline/queue_operation.dart'; // reuse stableMap to ensure identical hashing

String sha256of(String s) => sha256.convert(utf8.encode(s)).toString();

String makeDedupeKey({
  required String serverTarget,
  required String type,
  required Map<String, dynamic> payload,
}) {
  final stable = QueueOperation.stableMap(payload);
  final base = jsonEncode({'t': type, 'target': serverTarget, 'p': stable});
  return sha256of(base);
}
