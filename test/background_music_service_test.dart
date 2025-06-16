import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/services/background_music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ryanheise.just_audio');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async => null);
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('play initialise le service sans erreur', () async {
    await BackgroundMusicService.instance.play();
  });

  test('enabled permet d\'activer et désactiver la musique', () async {
    BackgroundMusicService.instance.enabled = false;
    await BackgroundMusicService.instance.play();
    BackgroundMusicService.instance.enabled = true;
    await BackgroundMusicService.instance.play();
  });
}
