import 'package:eatsoon/models/food_item.dart';

/// Urgency of a food item based on whole days left until expiry.
enum Urgency { expired, urgent, warning, fresh }

/// Whole days from [now] until [expiry], comparing calendar dates only.
/// Negative means already expired.
int daysUntilExpiry(DateTime expiry, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final expDay = DateTime(expiry.year, expiry.month, expiry.day);
  return expDay.difference(today).inDays;
}

/// Classification: red = expired or <= 2 days, amber = 3-5 days,
/// green = 6+ days.
Urgency urgencyForDays(int daysLeft) {
  if (daysLeft < 0) return Urgency.expired;
  if (daysLeft <= 2) return Urgency.urgent;
  if (daysLeft <= 5) return Urgency.warning;
  return Urgency.fresh;
}

/// Human label, e.g. "2 days left", "Expires today", "Expired 1 day ago".
String daysLeftLabel(int daysLeft) {
  if (daysLeft < 0) {
    final n = -daysLeft;
    return 'Expired $n ${n == 1 ? 'day' : 'days'} ago';
  }
  if (daysLeft == 0) return 'Expires today';
  if (daysLeft == 1) return '1 day left';
  return '$daysLeft days left';
}

/// Sort: most urgent first (expired first), then fewest days left,
/// then alphabetical.
int compareByUrgency(FoodItem a, FoodItem b, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final da = daysUntilExpiry(a.expiryDate, ref);
  final db = daysUntilExpiry(b.expiryDate, ref);
  if (da != db) return da.compareTo(db);
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Local 9:00am on the day [leadDays] before [expiry].
/// Returns null when that moment is not in the future — we never
/// schedule notifications in the past.
DateTime? reminderDateFor({
  required DateTime expiry,
  required int leadDays,
  required DateTime now,
}) {
  assert(leadDays >= 0, 'leadDays must be non-negative');
  final expDay = DateTime(expiry.year, expiry.month, expiry.day);
  final reminderDay = expDay.subtract(Duration(days: leadDays));
  final scheduled =
      DateTime(reminderDay.year, reminderDay.month, reminderDay.day, 9, 0);
  if (!scheduled.isAfter(now)) return null;
  return scheduled;
}

/// Stable positive notification id derived from the item id.
int notificationIdFor(String itemId) => itemId.hashCode & 0x7fffffff;
