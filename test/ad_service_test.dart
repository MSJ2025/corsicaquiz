import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/services/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/google_mobile_ads');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async => null);
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('init ne lance pas d\'exception', () async {
    await AdService.init();
  });

  test('loadInterstitial gère les erreurs sans exception', () async {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw PlatformException(code: '0', message: 'error');
    });
    expect(() => AdService.loadInterstitial(), returnsNormally);
  });
}
