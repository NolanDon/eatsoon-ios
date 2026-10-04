import 'package:eatsoon/logic/expiry_logic.dart';
import 'package:eatsoon/models/food_item.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local notifications for expiry reminders. All date math lives in
/// pure functions in expiry_logic.dart (unit-tested); this class only
/// talks to the OS plugin.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static Future<NotificationService> create() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(iOS: ios);
    await plugin.initialize(settings: settings);
    return NotificationService(plugin);
  }

  /// Asks iOS for alert/badge/sound permission. Call contextually,
  /// not on cold launch.
  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;
    return await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  /// Schedules (or re-schedules) the reminder for one item.
  /// Cancels any previous notification when there is nothing to schedule.
  Future<void> scheduleForItem(
    FoodItem item,
    int leadDays, {
    DateTime? now,
  }) async {
    final id = notificationIdFor(item.id);
    await _plugin.cancel(id: id);
    final when = reminderDateFor(
      expiry: item.expiryDate,
      leadDays: leadDays,
      now: now ?? DateTime.now(),
    );
    if (when == null) return;
    await _plugin.zonedSchedule(
      id: id,
      title: 'Eat soon: ${item.name}',
      body: 'Expires in $leadDays ${leadDays == 1 ? 'day' : 'days'}'
          ' — use it up!',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> cancelForItem(String itemId) =>
      _plugin.cancel(id: notificationIdFor(itemId));

  /// Rebuilds every notification, e.g. after the lead time changes.
  Future<void> rescheduleAll(List<FoodItem> items, int leadDays) async {
    for (final item in items) {
      await scheduleForItem(item, leadDays);
    }
  }
}
