import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  const app = 'eatsoon';
  const subject = 'fridge';
  final driver = await FlutterDriver.connect();
  try {
    final bytes = await File('../v3/backend/tests/fixtures/v3/$subject.jpg')
        .readAsBytes();
    final blurred = await File('../v3/backend/tests/fixtures/v3/blurred.jpg')
        .readAsBytes();
    final raw = await driver.requestData(
      jsonEncode({
        'action': 'native',
        'image': base64Encode(bytes),
        'blurred': base64Encode(blurred),
      }),
      timeout: const Duration(minutes: 4),
    );
    final result = jsonDecode(raw) as Map;
    await File('../v3/evidence/$app-simulator-native.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    if (result['ok'] != true) {
      throw StateError('Native fixture validation: ${result['error']}');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    await File('../v3/evidence/screenshots/$app-ios-dashboard.png')
        .writeAsBytes(await driver.screenshot());
    await driver.requestData(jsonEncode({'action': 'onboarding'}));
    await Future<void>.delayed(const Duration(seconds: 2));
    await File('../v3/evidence/screenshots/$app-ios-onboarding.png')
        .writeAsBytes(await driver.screenshot());
    await driver.tap(find.text('Get started'));
    await Future<void>.delayed(const Duration(seconds: 1));
    await File('../v3/evidence/screenshots/$app-ios-photo-step.png')
        .writeAsBytes(await driver.screenshot());
    final camera = jsonDecode(
      await driver.requestData(
        jsonEncode({'action': 'camera'}),
        timeout: const Duration(seconds: 30),
      ),
    );
    await File('../v3/evidence/$app-simulator-camera.json')
        .writeAsString(jsonEncode(camera));
    if (camera['ok'] != true) throw StateError('Camera fallback failed');
    // ignore: avoid_print
    print('$app: native photo quality and dashboard simulator checks passed.');
  } finally {
    await driver.close();
  }
}
