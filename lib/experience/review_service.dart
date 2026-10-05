import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import 'experience_preferences.dart';

/// No custom rating prompt, sentiment screening, incentive, or onboarding ask.
class ReviewPolicy {
  static bool eligible({
    required DateTime now,
    required DateTime firstUse,
    required DateTime? lastRequest,
    required int actions,
    required bool enabled,
  }) =>
      enabled &&
      actions >= 5 &&
      now.difference(firstUse).inDays >= 7 &&
      (lastRequest == null || now.difference(lastRequest).inDays >= 120);
}

class ReviewService {
  static bool _busy = false;
  static Future<void> recordMeaningfulAction() async {
    if (_busy) return;
    _busy = true;
    try {
      final prefs = ExperiencePreferences.instance;
      final store = prefs.store;
      if (store == null) return;
      final now = DateTime.now();
      final first =
          DateTime.tryParse(store.getString('experience.firstUse') ?? '') ??
          now;
      await store.setString('experience.firstUse', first.toIso8601String());
      final actions = prefs.integer('meaningfulActions', 0) + 1;
      await prefs.setInteger('meaningfulActions', actions);
      final last = DateTime.tryParse(
        store.getString('experience.reviewRequested') ?? '',
      );
      if (kDebugMode ||
          !ReviewPolicy.eligible(
            now: now,
            firstUse: first,
            lastRequest: last,
            actions: actions,
            enabled: prefs.flag('reviewRequests'),
          )) {
        return;
      }
      if (await InAppReview.instance.isAvailable()) {
        // Apple decides whether to display; never claim a rating was submitted.
        await store.setString(
          'experience.reviewRequested',
          now.toIso8601String(),
        );
        await InAppReview.instance.requestReview();
      }
    } catch (_) {
      // A review request must never interrupt the user's task.
    } finally {
      _busy = false;
    }
  }
}

/// Resolve the real published listing by bundle ID if no build-time ID is set.
/// Beta-only apps simply have no public review destination yet.
Future<bool> openAppStoreReview(String configuredId) async {
  var id = configuredId;
  final prefs = ExperiencePreferences.instance.store;
  if (id.isEmpty) id = prefs?.getString('experience.appStoreId') ?? '';
  if (id.isEmpty) {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final response = await (await client.getUrl(
        Uri.https('itunes.apple.com', '/lookup', {
          'bundleId': 'com.boxill.eatsoon',
        }),
      )).close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(
        await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 8)),
      ) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      for (final result in results) {
        if (result is Map &&
            result['bundleId'] == 'com.boxill.eatsoon' &&
            result['trackId'] is int) {
          id = '${result['trackId']}';
          await prefs?.setString('experience.appStoreId', id);
          break;
        }
      }
    } finally {
      client.close(force: true);
    }
  }
  if (!RegExp(r'^\d+$').hasMatch(id)) return false;
  return launchUrl(
    Uri.https('apps.apple.com', '/app/id$id', {'action': 'write-review'}),
    mode: LaunchMode.externalApplication,
  );
}
