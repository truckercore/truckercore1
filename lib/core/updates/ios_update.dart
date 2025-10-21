import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> checkIosUpdate({required String appStoreAppId}) async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    final res = await http.get(Uri.parse('https://downloads.truckercore.com/mobile/ios/latest.json'));
    if (res.statusCode != 200) return;
    final remote = jsonDecode(res.body) as Map<String, dynamic>;
    final latest = (remote['version'] as String?) ?? '';
    if (_isNewer(latest, pkg.version)) {
      final url = Uri.parse('https://apps.apple.com/app/id$appStoreAppId');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}

bool _isNewer(String a, String b) {
  int cv(String s) => s.split('.').fold(0, (p, e) => p * 100 + (int.tryParse(e) ?? 0));
  if (a.isEmpty || b.isEmpty) return false;
  return cv(a) > cv(b);
}
