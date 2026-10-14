import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanionException implements Exception {
  final String message;
  const CompanionException(this.message);
  @override
  String toString() => message;
}

typedef JsonTransport = Future<Map<String, dynamic>> Function(
  String path,
  String body,
  Map<String, String> headers,
);
typedef NativeCall = Future<dynamic> Function(
  String method,
  Map<String, dynamic> arguments,
);

/// Only the trusted server can access Gemini. Every AI request is bound to a
/// single-use server challenge and its exact JSON bytes using App Attest.
class AiClient {
  final String app;
  final JsonTransport transport;
  final NativeCall native;
  AiClient(this.app, {JsonTransport? transport, NativeCall? native})
    : transport = transport ?? _post,
      native =
          native ??
          ((method, arguments) =>
              const MethodChannel('com.boxill/companion')
                  .invokeMethod(method, arguments)
                  .timeout(const Duration(seconds: 30)));

  Future<Map<String, dynamic>> request(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final keyId = await native('attestKey', {}) as String?;
      if (keyId == null || keyId.isEmpty) {
        throw const CompanionException(
          'AI is unavailable on this device. You can still use the offline tools.',
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final registered = 'companion.attested.$app.$keyId';
      if (!prefs.containsKey(registered)) {
        final challenge = await _challenge(keyId, 'register');
        try {
          final proof = await native('attest', {
            'keyId': keyId,
            'data': challenge['nonce'],
          });
          final response = await transport(
            '/api/mobile/attest',
            jsonEncode({
              'schemaVersion': 1,
              'app': app,
              'keyId': keyId,
              'challengeId': challenge['challengeId'],
              'attestation': proof,
            }),
            {},
          );
          if (response['registered'] != true) throw const FormatException();
          await prefs.setBool(registered, true);
        } catch (_) {
          // Apple attests a key only once. If registration failed, retry with a
          // fresh key rather than repeatedly attesting a spent key.
          try {
            await native('forgetAttestKey', {});
          } catch (_) {}
          rethrow;
        }
      }
      final body = jsonEncode({'schemaVersion': 1, ...data});
      if (utf8.encode(body).length > 3000000) {
        throw const CompanionException(
          'This photo is too large. Choose a smaller photo.',
        );
      }
      final challenge = await _challenge(keyId, path);
      final assertion = await native('assert', {
        'keyId': keyId,
        'data': '${challenge['nonce']}\n$path\n$body',
      });
      final response = await transport(path, body, {
        'X-Boxill-App': app,
        'X-Boxill-Key-Id': keyId,
        'X-Boxill-Challenge-Id': challenge['challengeId'] as String,
        'X-Boxill-Assertion': assertion as String,
      });
      if (response['schemaVersion'] != 1) throw const FormatException();
      return response;
    } on CompanionException {
      rethrow;
    } on PlatformException {
      throw const CompanionException(
        'Device verification is unavailable. Try again later; offline tools still work.',
      );
    } on MissingPluginException {
      throw const CompanionException(
        'AI needs a supported iPhone or iPad. Offline tools still work.',
      );
    } on TimeoutException {
      throw const CompanionException(
        'The request took too long. Please try again.',
      );
    } on SocketException {
      throw const CompanionException(
        'Could not connect. Check your connection and try again.',
      );
    } catch (_) {
      throw const CompanionException(
        'The service returned an unreadable response. Please try again later.',
      );
    }
  }

  Future<Map<String, dynamic>> _challenge(String keyId, String purpose) async {
    final result = await transport(
      '/api/mobile/challenge',
      jsonEncode({
        'schemaVersion': 1,
        'app': app,
        'keyId': keyId,
        'purpose': purpose,
      }),
      {},
    );
    for (final key in ['nonce', 'challengeId']) {
      if (result[key] is! String ||
          (result[key] as String).isEmpty ||
          (result[key] as String).length > 512) {
        throw const FormatException();
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    String body,
    Map<String, String> headers,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      return await (() async {
        final request = await client.postUrl(Uri.https('boxillapps.com', path));
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        headers.forEach(request.headers.set);
        request.add(utf8.encode(body));
        final response = await request.close();
        if (response.statusCode != 200 && path == '/api/mobile/transfer') {
          final bytes = <int>[];
          await for (final chunk in response) {
            bytes.addAll(chunk);
            if (bytes.length > 4096) break;
          }
          String message =
              'Sharing is unavailable. Check your connection and try again.';
          try {
            final value = jsonDecode(utf8.decode(bytes));
            if (value is Map &&
                value['error'] is String &&
                (value['error'] as String).length <= 240) {
              message = value['error'] as String;
            }
          } catch (_) {}
          throw CompanionException(message);
        }
        if (response.statusCode != 200) {
          throw CompanionException(switch (response.statusCode) {
            400 || 422 => 'We could not read this photo clearly. Try another photo or enter the details manually.',
            429 => 'AI usage is temporarily limited. Please try again later.',
            401 ||
            403 => 'Device verification was rejected. Please try again later.',
            404 || 502 || 503 => 'Photo analysis is temporarily unavailable. Try again in a moment or enter the details manually.',
            _ => 'Could not complete the request. Please try again later.',
          });
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length >
              (path == '/api/mobile/transfer' ? 900000 : 128000)) {
            throw const FormatException();
          }
        }
        final json = jsonDecode(utf8.decode(bytes));
        if (json is! Map<String, dynamic> || json['schemaVersion'] != 1) {
          throw const FormatException();
        }
        return json;
      })().timeout(const Duration(seconds: 45));
    } finally {
      client.close(force: true);
    }
  }
}

String checkedText(dynamic value, {int max = 400}) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw const FormatException('Invalid text');
  }
  return value.trim();
}

int checkedInt(dynamic value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('Invalid number');
  }
  return value;
}
