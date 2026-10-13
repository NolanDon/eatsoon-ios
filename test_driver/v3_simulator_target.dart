import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/v3/brand.dart';
import 'package:eatsoon/v3/home.dart';
import 'package:eatsoon/v3/model.dart';

import '../test/v3_fixtures.dart';

const native = MethodChannel('com.boxill/vision');
Future<void> main() async {
  enableFlutterDriverExtension(
    handler: (message) async {
      try {
        final input = jsonDecode(message ?? '{}') as Map;
        final prefs = await SharedPreferences.getInstance();
        if (input['action'] == 'native') {
          final photo = Map<String, dynamic>.from(
            await native.invokeMethod('processPhoto', {
              'base64': input['image'],
            }) as Map,
          );
          final directory = await native.invokeMethod<String>('directory');
          var blurRejected = false;
          try {
            await native.invokeMethod('processPhoto', {
              'base64': input['blurred'],
            });
          } on PlatformException {
            blurRejected = true;
          }
          need(blurRejected, 'Blur was accepted');
          final report = <String, dynamic>{
            'ok': true,
            'width': photo['width'],
            'height': photo['height'],
            'sharpness': photo['sharpness'],
            'blurRejected': blurRejected,
            'invalidPathRejected':
                await native.invokeMethod('removePhoto', {
                  'file': '../outside.jpg',
                }) ==
                false,
          };
          String? cutout;
          if (appKind == 'clothing') {
            try {
              cutout = await native.invokeMethod<String>('cutout', {
                'file': photo['file'],
                'box': [0.0, 0.0, 1000.0, 1000.0],
              });
              final codec = await ui.instantiateImageCodec(
                await File('$directory/$cutout').readAsBytes(),
              );
              final frame = await codec.getNextFrame();
              final pixels = await frame.image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              var transparent = 0;
              if (pixels != null) {
                for (var i = 3; i < pixels.lengthInBytes; i += 4) {
                  if (pixels.getUint8(i) == 0) transparent++;
                }
              }
              need(transparent > 0, 'Cutout has no transparent pixels');
              report['transparentPixels'] = transparent;
              report['cutoutWidth'] = frame.image.width;
              report['cutoutHeight'] = frame.image.height;
              frame.image.dispose();
              codec.dispose();
            } on PlatformException catch (e) {
              need(
                (e.message ?? '').contains('inference context'),
                'Unexpected mask failure',
              );
              report['maskUnsupportedOnSimulator'] = true;
              report['cutoutValidated'] = false;
            }
          }
          if (appKind == 'ticket') {
            final redacted = Map<String, dynamic>.from(
              await native.invokeMethod('redactTicket', {'file': photo['file']})
                  as Map,
            );
            report['ticketRedactionProcessed'] = true;
            await native.invokeMethod('removePhoto', {
              'file': redacted['file'],
            });
          }
          await prefs.remove('v3.$appId.records');
          final store = V3Store(appId, appKind, prefs);
          await store.addAll([
            {
              ...fixture(appKind),
              'photo': photo['file'],
              ...(cutout == null ? <String, dynamic>{} : {'cutout': cutout}),
            },
            if (appKind == 'clothing')
              {
                ...fixture(appKind),
                'category': 'bottom',
                'name': 'Brown trousers',
                'color': 'brown',
              },
          ]);
          store.dispose();
          await prefs.setBool('v3.$appId.intro', true);
          await prefs.setBool('v3.$appId.wizard', true);
          runApp(
            MaterialApp(
              theme: v3Theme(),
              home: V3Home(key: UniqueKey()),
            ),
          );
          return jsonEncode(report);
        }
        if (input['action'] == 'onboarding') {
          await prefs.remove('v3.$appId.records');
          await prefs.remove('v3.$appId.intro');
          await prefs.remove('v3.$appId.wizard');
          runApp(
            MaterialApp(
              theme: v3Theme(),
              home: V3Home(key: UniqueKey()),
            ),
          );
          return jsonEncode({'ok': true});
        }
        if (input['action'] == 'camera') {
          try {
            final photo = await native.invokeMethod('capture');
            return jsonEncode({
              'ok': photo == null,
              'cancelled': photo == null,
            });
          } on PlatformException catch (e) {
            return jsonEncode({
              'ok': e.code == 'photo' && (e.message ?? '').contains('Camera'),
              'cameraUnavailableHandled': e.code == 'photo' && (e.message ?? '').contains('Camera'),
              'message': e.message,
            });
          }
        }
        return jsonEncode({'ok': false, 'error': 'Unknown action'});
      } catch (e) {
        return jsonEncode({'ok': false, 'error': '$e'});
      }
    },
  );
  runApp(MaterialApp(theme: v3Theme(), home: const V3Home()));
}
