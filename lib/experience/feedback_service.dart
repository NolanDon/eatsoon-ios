import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../v3/brand.dart' show appName;
import 'package:flutter/services.dart';

import 'feedback_form.dart';

const _feedbackChannel = MethodChannel('com.boxill/feedback');
bool feedbackComposerActive = false;

Future<FeedbackOutcome> sendFeedback({
  required String category,
  required String message,
}) async {
  if (feedbackComposerActive) return FeedbackOutcome.failed;
  feedbackComposerActive = true;
  try {
    if (Platform.isAndroid) {
      final query = {'subject': '$appName - $category', 'body': message}.entries
          .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}').join('&');
      final opened = await launchUrl(Uri(scheme: 'mailto', path: 'support@boxillapps.com', query: query), mode: LaunchMode.externalApplication);
      return opened ? FeedbackOutcome.opened : FeedbackOutcome.unavailable;
    }
    final result = await _feedbackChannel.invokeMethod<String>('sendFeedback', {
      'category': category,
      'message': message,
    });
    return switch (result) {
      'sent' => FeedbackOutcome.sent,
      'opened' => FeedbackOutcome.opened,
      'saved' => FeedbackOutcome.saved,
      'cancelled' => FeedbackOutcome.cancelled,
      'unavailable' => FeedbackOutcome.unavailable,
      _ => FeedbackOutcome.failed,
    };
  } finally {
    feedbackComposerActive = false;
  }
}
