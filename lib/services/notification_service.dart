import 'dart:convert';

//import 'package:flutter_app_badger/flutter_app_badger.dart';
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../util/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidNotificationDetails =
      AndroidNotificationDetails(
    Constants.channelID,
    Constants.applicationName,
    channelDescription: Constants.channelDescription,
    playSound: true,
    priority: Priority.high,
    importance: Importance.high,
  );

  static const DarwinNotificationDetails _darwinNotificationDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    threadIdentifier: Constants.channelID,
  );

  static const LinuxNotificationDetails _linuxNotificationDetails =
      LinuxNotificationDetails(
    urgency: LinuxNotificationUrgency.normal,
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidNotificationDetails,
    iOS: _darwinNotificationDetails,
    macOS: _darwinNotificationDetails,
    linux: _linuxNotificationDetails,
  );

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings("app_icon");

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: "Open notification");

    const initSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
        linux: initializationSettingsLinux);

    tz.initializeTimeZones();

    // Include routing for when this is initialized.
    await flutterLocalNotificationsPlugin.initialize(initSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
  }

  // NOTE: id should be the object's hashcode.
  // Store the object in the payload.
  Future<void> scheduleNotification({
    required int id,
    required DateTime warnDate,
    required String message,
    required String payload,
  }) async {
    final scheduleTime = tz.TZDateTime.from(warnDate, tz.local);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      Constants.applicationName,
      message,
      scheduleTime,
      _notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification({required int id}) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // NEEDS ROUTING.
  Future<void> onDidReceiveNotificationResponse(
      NotificationResponse? notificationResponse) async {
    final String? payload = notificationResponse?.payload;
    if (null == payload) {
      // Go through regular routing routine.
      return;
    }
    LineSplitter lineSplitter = const LineSplitter();
    List<String> entities = lineSplitter.convert(payload);

    if (entities.isEmpty || entities.length > 2) {
      // Go through regular routing routine.
      return;
    }
    // First string is the type, second is the id.
    switch (entities[0]) {
      case "Deadline":
        // Route to deadline screen, get by id.
        break;
      case "Reminder":
        // Route to reminder screen, get by id.
        break;
      default:
        // Regular routing.
        break;
    }
  }

  // Not sure whether to implement this.
  // void _addBadge() {
  //   FlutterAppBadger.updateBadgeCount(1);
  // }
  //
  // void _removeBadge() {
  //   FlutterAppBadger.removeBadge();
  // }

  Future<void> handleAppLaunch() async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    return onDidReceiveNotificationResponse(
        notificationAppLaunchDetails?.notificationResponse);
  }

  NotificationService._internal();
}