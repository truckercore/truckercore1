// lib/widgets/voice_coach.dart
import 'package:flutter_tts/flutter_tts.dart';

class VoiceCoach {
  final FlutterTts _tts = FlutterTts();

  Future<void> coach(String eventType) async {
    String msg;
    switch (eventType) {
      case 'fatigue':
        msg = 'You may be tired. Consider a short rest soon.';
        break;
      case 'distraction':
        msg = 'Eyes on the road. Stay focused.';
        break;
      default:
        msg = 'Drive safely.';
    }
    await _tts.speak(msg);
  }
}
