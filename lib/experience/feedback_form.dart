import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'experience_content.dart';

enum FeedbackOutcome { sent, saved, cancelled, unavailable, failed }

typedef FeedbackSender = Future<FeedbackOutcome> Function({
  required String category,
  required String message,
});

/// Support is always available, independently of the user's rating or review setting.
class FeedbackForm extends StatefulWidget {
  const FeedbackForm({super.key, required this.send});
  final FeedbackSender send;

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  String _category = 'General feedback';
  bool _sending = false;
  bool _loading = true;
  String? _status;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;
    _message.text = prefs.getString('feedback.draft') ?? '';
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final message = _message.text.trim();
    setState(() {
      _sending = true;
      _status = null;
    });
    try {
      await _prefs?.setString('feedback.draft', message);
      final outcome = await widget.send(category: _category, message: message);
      if (!mounted) return;
      if (outcome == FeedbackOutcome.sent) {
        await _prefs?.remove('feedback.draft');
        _message.clear();
      }
      if (!mounted) return;
      setState(() {
        _status = switch (outcome) {
          FeedbackOutcome.sent =>
            'Thank you for helping improve $appName! Your feedback is queued for sending to support@boxillapps.com.',
          FeedbackOutcome.saved => 'Your email was saved as a draft. You can send it from Mail when you’re ready.',
          FeedbackOutcome.cancelled =>
            'Sending cancelled. Your feedback draft is still here.',
          FeedbackOutcome.unavailable => 'Set up an account in Apple Mail to send feedback, or email support@boxillapps.com from your preferred email app. Your draft is saved.',
          FeedbackOutcome.failed => 'Your feedback could not be sent. Your draft is saved; please try again or email support@boxillapps.com.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Your feedback could not be sent. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: const Icon(Icons.feedback_outlined),
    title: const Text('Send feedback'),
    subtitle: const Text('Ideas, questions, or something that needs fixing'),
    maintainState: true,
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    children: [
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Topic'),
              items:
                  const [
                        'General feedback',
                        'Report a problem',
                        'Feature idea',
                        'Question',
                      ]
                      .map(
                        (topic) =>
                            DropdownMenuItem(value: topic, child: Text(topic)),
                      )
                      .toList(),
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              enabled: !_sending && !_loading,
              minLines: 4,
              maxLines: 8,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your feedback',
                hintText: 'Tell us what worked, what didn’t, or what you’d like to see.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Please write at least 10 characters.'
                  : null,
              onChanged: (value) => _prefs?.setString('feedback.draft', value),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sent to support@boxillapps.com. Please avoid sensitive personal information.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending || _loading ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Sending…' : 'Send feedback'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_status!)),
            ],
          ],
        ),
      ),
    ],
  );
}
