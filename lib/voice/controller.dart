import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'intents.dart';

class VoiceController {
  final stt.SpeechToText sttEngine = stt.SpeechToText();
  Future<void> init() async => sttEngine.initialize();
  Future<void> startListening(Function(VoiceIntent?) onIntent) async {
    await sttEngine.listen(onResult: (r){
      final intent = parseIntent(r.recognizedWords);
      if (r.finalResult) onIntent(intent);
    });
  }
  Future<void> stop() => sttEngine.stop();
}
