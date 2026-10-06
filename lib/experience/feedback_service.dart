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
    final result = await _feedbackChannel.invokeMethod<String>('sendFeedback', {
      'category': category,
      'message': message,
    });
    return switch (result) {
      'sent' => FeedbackOutcome.sent,
      'saved' => FeedbackOutcome.saved,
      'cancelled' => FeedbackOutcome.cancelled,
      'unavailable' => FeedbackOutcome.unavailable,
      _ => FeedbackOutcome.failed,
    };
  } finally {
    feedbackComposerActive = false;
  }
}
