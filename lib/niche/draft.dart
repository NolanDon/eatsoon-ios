import 'package:flutter/material.dart';

import 'ai_client.dart';
import 'journal.dart';

class DraftContext {
  final String app, workflow;
  final AiClient? client;
  const DraftContext(this.app, this.workflow, {this.client});
  Future<Record?> extract(BuildContext context, String notes) async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send these notes to AI?'),
        content: SingleChildScrollView(
          child: Text(
            'Send these notes to Google Gemini for an editable draft. Check the details before keeping it.\n\n$notes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agree & send'),
          ),
        ],
      ),
    );
    if (consent != true) return null;
    final response = await (client ?? AiClient(app)).request(
      '/api/mobile/workspace-draft',
      {'app': app, 'workflow': workflow, 'notes': notes},
    );
    check(
      response['values'] is Map && response['missing'] is List,
      'The service returned an invalid draft.',
    );
    return Map<String, dynamic>.from(response['values'] as Map);
  }
}
