import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/experience/experience_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsoon/experience/review_service.dart';

void main() {
  final now = DateTime(2026, 10, 5);
  bool eligible({
    int age = 7,
    int actions = 5,
    int days = 3,
    int fresh = 5,
    int requests = 0,
    int? lastDays,
    bool enabled = true,
  }) => ReviewPolicy.eligible(
    now: now,
    firstUse: now.subtract(Duration(days: age)),
    lastRequest: lastDays == null
        ? null
        : now.subtract(Duration(days: lastDays)),
    actions: actions,
    enabled: enabled,
    requests: requests,
    actionsSinceRequest: fresh,
    meaningfulDays: days,
  );

  test('requires experienced use over several days and consent', () {
    expect(eligible(), isTrue);
    expect(eligible(age: 6), isFalse);
    expect(eligible(actions: 4), isFalse);
    expect(eligible(days: 2), isFalse);
    expect(eligible(enabled: false), isFalse);
    expect(eligible(fresh: 4), isFalse);
  });
  test('requests become less frequent at exact cooldown boundaries', () {
    expect(eligible(requests: 1, lastDays: 119), isFalse);
    expect(eligible(requests: 1, lastDays: 120), isTrue);
    expect(eligible(requests: 2, lastDays: 239), isFalse);
    expect(eligible(requests: 2, lastDays: 240), isTrue);
    expect(eligible(requests: 3, lastDays: 364), isFalse);
    expect(eligible(requests: 3, lastDays: 365), isTrue);
    expect(eligible(requests: 10, lastDays: 364), isFalse);
  });
  test('stopping-point checks do not invent meaningful actions or usage days', () async {
    SharedPreferences.setMockInitialValues({});
    await ExperiencePreferences.initialize();
    await ReviewService.considerReview();
    final store = ExperiencePreferences.instance.store!;
    expect(store.getInt('experience.meaningfulActions'), isNull);
    expect(store.getStringList('experience.meaningfulDates'), isNull);
    await ReviewService.recordMeaningfulAction(request: false);
    await ReviewService.recordMeaningfulAction(request: false);
    expect(store.getInt('experience.meaningfulActions'), 2);
    expect(store.getStringList('experience.meaningfulDates')!.length, 1);
    await ReviewService.considerReview();
    expect(store.getInt('experience.meaningfulActions'), 2);
    expect(store.getStringList('experience.meaningfulDates')!.length, 1);
    expect(store.getString('experience.reviewRequested'), isNull);
  });

}
