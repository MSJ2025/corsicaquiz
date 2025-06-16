import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notifChannel = MethodChannel('dexterous.com/flutter/local_notifications');
  const firebaseChannel = MethodChannel('plugins.flutter.io/firebase_messaging');

  setUp(() {
    notifChannel.setMockMethodCallHandler((MethodCall methodCall) async => null);
    firebaseChannel.setMockMethodCallHandler((MethodCall methodCall) async => null);
  });

  tearDown(() {
    notifChannel.setMockMethodCallHandler(null);
    firebaseChannel.setMockMethodCallHandler(null);
  });

  test('init ne lance pas d\'exception', () async {
    await NotificationService.init();
  });

  test('disable ne lance pas d\'exception', () async {
    await NotificationService.disable();
  });
}
