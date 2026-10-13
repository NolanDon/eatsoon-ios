import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  try {
    final raw = await driver.requestData(
      'verify',
      timeout: const Duration(minutes: 3),
    );
    final result = jsonDecode(raw) as Map<String, dynamic>;
    await File('../niche-upgrade/evidence/eatsoon-live-device-ai.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    if (result['ok'] != true) {
      throw StateError('Real device AI request failed: ${result['error']}');
    }
    final response = result['response'] as Map<String, dynamic>;
    if (response['schemaVersion'] != 1 || response['values'] is! Map) {
      throw StateError('Invalid server output');
    }
    // ignore: avoid_print
    print(
      'eatsoon: genuine production App Attest and Gemini response verified using synthetic source.',
    );
  } finally {
    await driver.close();
  }
}
