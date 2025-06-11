import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotif.initialize(initSettings);

    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _showNotification(notification.title, notification.body);
      }
    });
  }

  static Future<void> _showNotification(String? title, String? body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('default', 'Notifications',
          importance: Importance.max, priority: Priority.high),
    );
    await _localNotif.show(0, title, body, details);
  }
}
