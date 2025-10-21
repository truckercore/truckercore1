// Dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class CoiUploadService {
  final _sb = Supabase.instance.client;

  Future<void> uploadCOI({required File file, required String mime}) async {
    final bytes = await file.length();
    final resp = await _sb.functions.invoke('signed-coi-upload', body: {
      'fileName': file.uri.pathSegments.last,
      'mime': mime,
      'sizeBytes': bytes,
    });
    final data = resp.data as Map<String, dynamic>;
    final signedUrl = data['signedUrl'] as String;
    final put = await http.put(Uri.parse(signedUrl), headers: {'Content-Type': mime}, body: await file.readAsBytes());
    if (put.statusCode >= 300) {
      throw Exception('COI upload failed: ${put.statusCode}');
    }
  }
}
