import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

const String baseUrl = 'https://truckercore12.vercel.app';

class PushNotificationService {
  Future<void> registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      final session = Supabase.instance.client.auth.currentSession;
      if (token == null || session == null) return;

      await http.post(
        Uri.parse('$baseUrl/api/push/register-mobile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'pushToken': token,
          'deviceName': 'TruckerCore Driver App',
        }),
      );

      print('Push token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      print('Push token registration error: $e');
    }
  }

  void listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 PUSH: ${message.notification?.title} — ${message.notification?.body}');
      // TODO: Show local notification using flutter_local_notifications
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 APP OPENED FROM PUSH: ${message.notification?.title}');
      // TODO: Navigate to relevant screen based on message.data['url']
    });
  }
}