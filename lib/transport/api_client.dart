import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../offline/queue_operation.dart';

class ApiClient {
  final _supabase = Supabase.instance.client;

  Future<bool> hasNetwork() async {
    try {
      final res = await InternetAddress.lookup('example.com');
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<({bool success, bool duplicate, int status, String? error})> dispatchOp(QueueOperation op) async {
    if (op.serverTarget.startsWith('rpc:')) {
      final fn = op.serverTarget.substring(4);
      return _callRpc(fn, op);
    } else if (op.serverTarget.startsWith('POST:')) {
      final path = op.serverTarget.substring(5);
      // Prefer Supabase Functions when path is relative (e.g., "/ingest/positions")
      if (path.startsWith('/')) {
        return _invokeFunction(path, op);
      }
      return _postHttp(path, op);
    } else {
      return (success: false, duplicate: false, status: 0, error: 'Unknown target "${op.serverTarget}"');
    }
  }

  // Supabase Postgres RPC
  Future<({bool success, bool duplicate, int status, String? error})> _callRpc(String fn, QueueOperation op) async {
    final params = {...op.payload, '_dedupe_key': op.dedupeKey};
    try {
      // supabase_flutter v2: rpc returns dynamic; let it throw PostgrestException on error
      await _supabase.rpc(fn, params: params);
      return (success: true, duplicate: false, status: 200, error: null);
    } on PostgrestException catch (e) {
      final msg = e.message;
      final duplicate = _isDuplicate(msg);
      final code = e.code;
      return (success: duplicate, duplicate: duplicate, status: duplicate ? 409 : (code == '409' ? 409 : 500), error: msg);
    } catch (e) {
      return (success: false, duplicate: false, status: 500, error: e.toString());
    }
  }

  // Supabase Edge Function (invoke) with auth
  Future<({bool success, bool duplicate, int status, String? error})> _invokeFunction(String path, QueueOperation op) async {
    try {
      final resp = await _supabase.functions.invoke(
        path.replaceFirst(RegExp('^/'), ''), // remove leading slash for invoke
        body: {...op.payload, '_dedupe_key': op.dedupeKey},
      );
      final status = resp.status;
      if (status >= 200 && status < 300) {
        return (success: true, duplicate: false, status: status, error: null);
      }
      final bodyStr = resp.data?.toString();
      if (status == 409 || _isDuplicate(bodyStr ?? '')) {
        return (success: false, duplicate: true, status: 409, error: bodyStr);
      }
      return (success: false, duplicate: false, status: status, error: bodyStr);
    } catch (e) {
      return (success: false, duplicate: false, status: 500, error: e.toString());
    }
  }

  // Plain HTTP POST fallback (non-Supabase endpoint)
  Future<({bool success, bool duplicate, int status, String? error})> _postHttp(String urlOrPath, QueueOperation op) async {
    final uri = Uri.parse(urlOrPath);
    final jwt = _supabase.auth.currentSession?.accessToken;
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', if (jwt != null) 'Authorization': 'Bearer $jwt'},
      body: jsonEncode({...op.payload, '_dedupe_key': op.dedupeKey}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (success: true, duplicate: false, status: res.statusCode, error: null);
    }
    if (res.statusCode == 409 || _isDuplicate(res.body)) {
      return (success: false, duplicate: true, status: 409, error: res.body);
    }
    return (success: false, duplicate: false, status: res.statusCode, error: res.body);
  }

  bool _isDuplicate(String msg) {
    final m = msg.toLowerCase();
    return m.contains('duplicate') ||
        m.contains('already exists') ||
        m.contains('conflict') ||
        m.contains('unique constraint');
  }
}
