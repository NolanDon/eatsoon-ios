import 'dart:convert';

import 'package:flutter_driver/driver_extension.dart';

import 'package:eatsoon/main.dart' as application;
import 'package:eatsoon/niche/ai_client.dart';

Future<void> main() async {
  enableFlutterDriverExtension(
    handler: (message) async {
      try {
        final response = await AiClient('eatsoon')
            .request('/api/mobile/workspace-draft', {
              'app': 'eatsoon',
              'workflow': 'opened-pack',
              'notes': "Yogurt, 4 portions. Opened October 12, 2026. Best before October 15, 2026. Fridge. Label says refrigerate after opening.",
            });
        return jsonEncode({
          'ok': true,
          'syntheticSource': true,
          'response': response,
        });
      } catch (error) {
        return jsonEncode({
          'ok': false,
          'error': '$error',
          'syntheticSource': true,
        });
      }
    },
  );
  await application.main();
}
