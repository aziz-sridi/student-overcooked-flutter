import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationStore {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  static const _key = 'student_overcooked_notifications_v1';
  static const _focusNotificationId = 1001;
  static const _channelId = 'student_overcooked_focus';
  static const _channelName = 'Focus sessions';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool?> permissionGranted = ValueNotifier<bool?>(null);
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _focusNotificationScheduled = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Focus timer and study-session alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final settings = InitializationSettings(
      android: kIsWeb
          ? null
          : const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: kIsWeb ? null : darwin,
      macOS: kIsWeb ? null : darwin,
    );

    try {
      await _plugin.initialize(settings: settings);
    } catch (_) {
      // Keep the preference available on platforms without a notification host.
    }

    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_key) ?? false;
    await _refreshPermissionStatus();
    if (permissionGranted.value == false && enabled.value) {
      enabled.value = false;
      await prefs.setBool(_key, false);
    }
    _initialized = true;
  }

  Future<bool> setEnabled(bool value) async {
    if (value) {
      final granted = await requestPermission();
      enabled.value = granted;
    } else {
      enabled.value = false;
      permissionGranted.value = false;
      await cancelFocusNotification();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled.value);
    return enabled.value;
  }

  Future<bool> requestPermission() async {
    bool? result;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        result = await android.requestNotificationsPermission();
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        result = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final macOS = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macOS != null) {
        result = await macOS.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final web = _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >();
      if (web != null) {
        if (web.permissionStatus != WebNotificationPermission.granted) {
          await web.requestNotificationsPermission();
        }
        result = web.permissionStatus == WebNotificationPermission.granted;
      }
    } catch (_) {
      result = false;
    }

    permissionGranted.value = result ?? false;
    return permissionGranted.value!;
  }

  Future<void> _refreshPermissionStatus() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        permissionGranted.value = await android.areNotificationsEnabled();
        return;
      }

      final web = _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >();
      if (web != null) {
        permissionGranted.value =
            web.permissionStatus == WebNotificationPermission.granted;
      }
    } catch (_) {
      permissionGranted.value = false;
    }
  }

  Future<void> scheduleFocusComplete(Duration remaining) async {
    await cancelFocusNotification();
    if (!enabled.value || remaining <= Duration.zero || kIsWeb) return;

    try {
      await _plugin.zonedSchedule(
        id: _focusNotificationId,
        title: 'Focus session complete',
        body: 'Nice work. Take a short break before the next round.',
        scheduledDate: tz.TZDateTime.now(tz.local).add(remaining),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'focus_complete',
      );
      _focusNotificationScheduled = true;
    } catch (_) {
      _focusNotificationScheduled = false;
    }
  }

  Future<void> completeFocusNotification() async {
    final wasScheduled = _focusNotificationScheduled;
    _focusNotificationScheduled = false;
    if (!enabled.value || wasScheduled) return;
    await showFocusComplete();
  }

  Future<void> showFocusComplete() async {
    if (!enabled.value) return;
    try {
      await _plugin.show(
        id: _focusNotificationId,
        title: 'Focus session complete',
        body: 'Nice work. Take a short break before the next round.',
        notificationDetails: _details,
        payload: 'focus_complete',
      );
    } catch (_) {
      // The in-app timer still completes if notifications are unavailable.
    }
  }

  Future<void> showTestNotification() async {
    if (!enabled.value) return;
    try {
      await _plugin.show(
        id: 1002,
        title: 'Notifications are ready',
        body: 'Student Overcooked can alert you when a focus session ends.',
        notificationDetails: _details,
        payload: 'notification_test',
      );
    } catch (_) {
      // The settings screen reports permission state separately.
    }
  }

  Future<void> cancelFocusNotification() async {
    _focusNotificationScheduled = false;
    try {
      await _plugin.cancel(id: _focusNotificationId);
    } catch (_) {
      // Nothing was scheduled, or the platform does not support cancellation.
    }
  }
}
