import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class SignedHttp {
  final String secret;
  SignedHttp(this.secret);

  Map<String,String> _sign(String path, String body){
    final ts = DateTime.now().toUtc().toIso8601String();
    final payload = '$ts|$path|$body';
    final sig = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload)).toString();
    return {'X-Signature': sig,'X-Timestamp': ts};
  }

  Future<http.Response> post(Uri url, {Map<String,String>? headers, Object? body}) {
    final b = body is String ? body : jsonEncode(body);
    final h = {...?headers, ..._sign(url.path, b)};
    return http.post(url, headers: h, body: b);
  }
}

class SignedAdmin {
  final String secret;
  SignedAdmin(this.secret);

  Map<String, String> _sig(String path, String body) {
    final ts = DateTime.now().toUtc().toIso8601String();
    final mac = Hmac(sha256, utf8.encode(secret));
    final sig = mac.convert(utf8.encode('$ts|$path|$body')).toString();
    return {'x-timestamp': ts, 'x-signature': sig, 'content-type': 'application/json'};
  }

  Future<http.Response> post(Uri url, Object body) {
    final b = jsonEncode(body);
    return http.post(url, headers: _sig(url.path, b), body: b);
  }
}
