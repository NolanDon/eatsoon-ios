import 'dart:async';

import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import 'experience_preferences.dart';
import 'feedback_service.dart';

/// No custom rating prompt, sentiment screening, incentive, or onboarding ask.
final reviewNavigationObserver = ReviewNavigationObserver();

class ReviewNavigationObserver extends NavigatorObserver {
  Route<dynamic>? currentRoute;
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    currentRoute = topRoute;
  }
}

class ReviewPolicy {
  static int cooldownDays(int requests) => requests <= 1
      ? 120
      : requests == 2
      ? 240
      : 365;
  static bool eligible({
    required DateTime now,
    required DateTime firstUse,
    required DateTime? lastRequest,
    required int actions,
    required bool enabled,
    int requests = 0,
    int actionsSinceRequest = 5,
    int meaningfulDays = 3,
  }) =>
      enabled &&
      actions >= 5 &&
      actionsSinceRequest >= 5 &&
      meaningfulDays >= 3 &&
      now.difference(firstUse).inDays >= 7 &&
      (lastRequest == null ||
          now.difference(lastRequest).inDays >= cooldownDays(requests));
}

class ReviewService {
  static bool _busy = false;
  static bool _scheduled = false;
  static Future<void> recordMeaningfulAction({bool request = true}) =>
      _consider(recordAction: true, request: request);

  /// A natural stopping point can check previously earned eligibility.
  static Future<void> considerReview({bool Function()? canPrompt}) =>
      _consider(recordAction: false, canPrompt: canPrompt);

  static Future<void> _consider({
    required bool recordAction,
    bool request = true,
    bool Function()? canPrompt,
  }) async {
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
      final actions =
          prefs.integer('meaningfulActions', 0) + (recordAction ? 1 : 0);
      if (recordAction) await prefs.setInteger('meaningfulActions', actions);
      final dates = store.getStringList('experience.meaningfulDates') ?? [];
      final today = '${now.year}-${now.month}-${now.day}';
      if (recordAction && !dates.contains(today)) {
        dates.add(today);
        await store.setStringList(
          'experience.meaningfulDates',
          dates.take(30).toList(),
        );
      }
      final requests = prefs.integer('reviewRequestCount', 0);
      final previousActions = prefs.integer('actionsAtReviewRequest', 0);
      final last = DateTime.tryParse(
        store.getString('experience.reviewRequested') ?? '',
      );
      if (!request ||
          kDebugMode ||
          !ReviewPolicy.eligible(
            now: now,
            firstUse: first,
            lastRequest: last,
            actions: actions,
            enabled: prefs.flag('reviewRequests'),
            requests: requests,
            actionsSinceRequest: actions - previousActions,
            meaningfulDays: dates.length,
          )) {
        return;
      }
      // Let completion UI settle; never put a rating dialog over a sheet or alert.
      if (!_scheduled) {
        _scheduled = true;
        unawaited(_requestWhenSettled(actions, requests, canPrompt));
      }
    } catch (_) {
      // A review request must never interrupt the user's task.
    } finally {
      _busy = false;
    }
  }

  static Future<void> _requestWhenSettled(
    int actions,
    int requests,
    bool Function()? canPrompt,
  ) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final route = reviewNavigationObserver.currentRoute;
      await Future<void>.delayed(const Duration(seconds: 6));
      if ((canPrompt != null && !canPrompt()) ||
          feedbackComposerActive ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          WidgetsBinding.instance.platformDispatcher.views.any(
            (view) => view.viewInsets.bottom > 0,
          ) ||
          route is! PageRoute ||
          !route.isCurrent ||
          reviewNavigationObserver.currentRoute != route ||
          !ExperiencePreferences.instance.flag('reviewRequests')) {
        return;
      }
      if (!await InAppReview.instance.isAvailable()) return;
      final store = ExperiencePreferences.instance.store;
      if (store == null) return;
      // These track API attempts, never claim a prompt appeared or a rating was submitted.
      await store.setString(
        'experience.reviewRequested',
        DateTime.now().toIso8601String(),
      );
      await store.setInt('experience.reviewRequestCount', requests + 1);
      await store.setInt('experience.actionsAtReviewRequest', actions);
      await InAppReview.instance.requestReview();
    } catch (_) {
      // Ratings must never prevent the app from completing its task.
    } finally {
      _scheduled = false;
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
