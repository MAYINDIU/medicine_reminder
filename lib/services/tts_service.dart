import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    await _tts.setLanguage('bn-BD'); // try bn-BD or bn-IN
    await _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
}
