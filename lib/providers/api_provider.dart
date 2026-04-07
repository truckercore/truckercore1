import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truckercore1/services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(baseUrl: 'https://your-api-base-url.com/api');
});
