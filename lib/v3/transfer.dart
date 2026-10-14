import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../niche/ai_client.dart';
import 'brand.dart';
import 'model.dart';
import 'photo_flow.dart';

const transferPath = '/api/mobile/transfer';
const transferChunkSize = 250000;
String normalizeShareCode(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri != null && uri.scheme == 'https' && uri.host == 'boxillapps.com') {
    final parameters = Uri.splitQueryString(uri.fragment);
    need(
      parameters['app'] == apiAppId,
      'Open this code in the app it belongs to.',
    );
    input = parameters['code'] ?? '';
  }
  final code = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  need(
    RegExp(r'^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{16}$').hasMatch(code),
    'Enter the full 16-character share code.',
  );
  return code;
}

String formatShareCode(String code) =>
    List.generate(4, (i) => code.substring(i * 4, i * 4 + 4)).join('-');
String transferLink(String code) =>
    'https://boxillapps.com/transfer#app=$apiAppId&code=$code';
Set<String> sharedPhotoNames(Object? value) {
  final names = <String>{};
  void visit(Object? v) {
    if (v is List) {
      for (final child in v) {
        visit(child);
      }
    } else if (v is Map) {
      for (final entry in v.entries) {
        if (['photo', 'cutout', 'image'].contains(entry.key) &&
            entry.value != null) {
          need(
            entry.value is String &&
                RegExp(r'^[A-Za-z0-9-]+\.(jpg|png)$')
                    .hasMatch(entry.value as String),
            'Invalid saved photo.',
          );
          names.add(entry.value as String);
        } else {
          visit(entry.value);
        }
      }
    }
  }

  visit(value);
  return names;
}

Object? replaceSharedPhotos(Object? value, Map<String, String> mapping) {
  if (value is List) {
    return value.map((v) => replaceSharedPhotos(v, mapping)).toList();
  }
  if (value is Map) {
    return value.map(
      (key, v) => MapEntry(
        key,
        ['photo', 'cutout', 'image'].contains(key) && v is String
            ? mapping[v] ?? v
            : replaceSharedPhotos(v, mapping),
      ),
    );
  }
  return value;
}

class TransferClient {
  final V3Store store;
  final String directory;
  final SharedPreferences preferences;
  final AiClient api;
  TransferClient(this.store, this.directory, this.preferences, {AiClient? api})
    : api = api ?? AiClient(apiAppId);
  String get receiptsKey => 'v3.$appId.shares';
  List<Item> get receipts {
    try {
      return (jsonDecode(preferences.getString(receiptsKey) ?? '[]') as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Item> call(String operation, [Item extra = const {}]) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        return await api.request(transferPath, {
          'app': apiAppId,
          'operation': operation,
          ...extra,
        });
      } on CompanionException catch (error) {
        if (attempt == 4 ||
            !(error.message.toLowerCase().contains('too many requests') ||
                error.message.toLowerCase().contains('temporarily limited'))) {
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: 15 * (attempt + 1)));
      }
    }
    throw const FormatException('Sharing is temporarily unavailable.');
  }

  Future<Item> create(
    List<Item> items,
    List<Item> outfits, {
    required void Function(String) progress,
  }) async {
    need(items.isNotEmpty, 'Choose something to share.');
    final files = <Item>[], bytesByName = <String, Uint8List>{};
    final cleanItems = items.map((v) {
      final item = {...v}..remove('sourceTransferId');
      if ((appKind == 'plant' || appKind == 'clothing') &&
          item['cutout'] != null) {
        item['photo'] = item['cutout'];
      }
      if (appKind == 'drawing') item.remove('photo');
      return item;
    }).toList();
    final names = sharedPhotoNames(cleanItems);
    need(names.length <= 300, 'Choose fewer photos to share at once.');
    var total = 0;
    for (final name in names) {
      final encoded = await vision.invokeMethod<String>('transferPhoto', {
        'file': name,
      });
      need(encoded != null, 'A saved photo is missing.');
      final bytes = base64Decode(encoded!);
      total += bytes.length;
      need(total <= 40000000, 'Choose fewer photos to share at once.');
      bytesByName[name] = bytes;
      files.add({
        'name': name,
        'bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'chunks': (bytes.length / transferChunkSize).ceil(),
      });
    }
    final manifest = {
      'version': 1,
      'app': apiAppId,
      'kind': appKind,
      'items': cleanItems,
      'outfits': outfits,
      'reminders': preferences.getBool('v3.$appId.reminders') ?? false,
      'files': files,
    };
    store.decode(
      jsonEncode({
        'version': 3,
        'app': appId,
        'items': cleanItems,
        'outfits': outfits,
        'plans': [],
      }),
    );
    progress('Preparing your code');
    final receipt = await call('create', {'manifest': manifest});
    final code = receipt['code'] as String;
    // Keep a recoverable receipt before uploading so failed uploads can be revoked.
    final local = {
      ...receipt,
      'itemIds': items.map((v) => v['id']).toList(),
      'outfitIds': outfits.map((v) => v['id']).toList(),
      'count': outfits.isNotEmpty ? outfits.length : items.length,
      'entity': outfits.isNotEmpty
          ? 'outfits'
          : switch (appKind) {
              'plant' => 'plants',
              'fridge' => 'food items',
              'meal' => 'recipes',
              'drawing' => 'comics',
              'clothing' => 'clothing items',
              'knitting' => 'patterns',
              'goal' => 'goals',
              'wrapping' => 'wrap plans',
              'mending' => 'repairs',
              _ => 'records',
            },
    };
    await preferences.setString(
      receiptsKey,
      jsonEncode([local, ...receipts].take(40).toList()),
    );
    try {
      var done = 0;
      final count = files.fold<int>(0, (n, f) => n + f['chunks'] as int);
      for (final file in files) {
        final bytes = bytesByName[file['name']]!;
        for (var i = 0; i < (file['chunks'] as int); i++) {
          progress('Uploading photo ${++done} of $count');
          final end = ((i + 1) * transferChunkSize).clamp(0, bytes.length);
          await call('upload', {
            'code': code,
            'name': file['name'],
            'index': i,
            'base64': base64Encode(bytes.sublist(i * transferChunkSize, end)),
          });
        }
      }
      await call('publish', {'code': code});
      local['state'] = 'ready';
      await remember(local);
      return local;
    } catch (_) {
      try {
        await call('revoke', {'code': code});
        local['state'] = 'revoked';
        await remember(local);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> remember(Item receipt) async {
    final updated = receipts
        .where((r) => r['code'] != receipt['code'])
        .toList();
    await preferences.setString(
      receiptsKey,
      jsonEncode([receipt, ...updated].take(40).toList()),
    );
  }

  Future<Item> status(Item receipt) async {
    final state = await call('status', {'code': receipt['code']});
    final updated = {...receipt, ...state};
    await remember(updated);
    return updated;
  }

  Future<void> revoke(Item receipt) async {
    final state = await call('revoke', {'code': receipt['code']});
    await remember({...receipt, ...state});
  }

  Future<({int count, bool reminders})> redeem(
    String input, {
    required void Function(String) progress,
  }) async {
    final code = normalizeShareCode(input),
        receiptId = sha256.convert(utf8.encode(code)).toString();
    if (store.items.any((v) => v['sourceTransferId'] == receiptId)) {
      try {
        await call('complete', {'code': code});
      } catch (_) {}
      return (count: 0, reminders: false);
    }
    progress('Checking your code');
    final response = await call('redeem', {'code': code});
    final manifest = Map<String, dynamic>.from(response['manifest'] as Map);
    need(
      manifest['app'] == apiAppId &&
          manifest['kind'] == appKind &&
          manifest['version'] == 1,
      'This collection belongs to another app.',
    );
    final incoming = (manifest['items'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    final outfits = (manifest['outfits'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    store.decode(
      jsonEncode({
        'version': 3,
        'app': appId,
        'items': incoming,
        'outfits': outfits,
        'plans': [],
      }),
    );
    need(
      store.items.length + incoming.length <= 500,
      'Your collection is full.',
    );
    final files = (manifest['files'] as List)
        .map((f) => Map<String, dynamic>.from(f as Map))
        .toList();
    final expected = sharedPhotoNames(incoming);
    need(
      files.length == expected.length &&
          files.every((f) => expected.contains(f['name'])),
      'A shared photo is missing.',
    );
    final mapping = <String, String>{}, written = <File>[];
    try {
      var done = 0;
      for (final file in files) {
        final name = file['name'] as String;
        final size = whole(file['bytes'], min: 1, max: 3000000),
            chunks = whole(file['chunks'], min: 1, max: 12);
        need(
          chunks == (size / transferChunkSize).ceil(),
          'Invalid shared photo.',
        );
        progress('Importing photo ${++done} of ${files.length}');
        final buffer = BytesBuilder(copy: false);
        for (var i = 0; i < chunks; i++) {
          final part = await call('download', {
            'code': code,
            'name': name,
            'index': i,
          });
          final bytes = base64Decode(part['base64'] as String);
          need(bytes.length <= transferChunkSize, 'Invalid photo chunk.');
          buffer.add(bytes);
        }
        final bytes = buffer.takeBytes();
        need(
          bytes.length == size &&
              sha256.convert(bytes).toString() == file['sha256'],
          'A photo did not transfer correctly. Try importing again.',
        );
        final png =
            bytes.length >= 8 &&
            bytes.take(8).toList().join(',') == '137,80,78,71,13,10,26,10';
        final jpg =
            bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        need(png || jpg, 'Invalid shared image.');
        final target = '${uniqueId()}-${written.length}.${png ? 'png' : 'jpg'}';
        final local = File('$directory/$target');
        await local.writeAsBytes(bytes, flush: true);
        written.add(local);
        mapping[name] = target;
      }
      final replaced = (replaceSharedPhotos(incoming, mapping) as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      for (final item in replaced) {
        item['sharedReminders'] = manifest['reminders'] == true && item['sharedReminders'] != false;
      }
      await store.mergeShared(replaced, outfits, receiptId);
    } catch (_) {
      for (final file in written) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    }
    // Import is committed locally before server deletion. Retrying this code
    // is idempotent even if the final acknowledgement loses connectivity.
    try {
      await call('complete', {'code': code});
    } catch (_) {}
    return (count: incoming.length, reminders: manifest['reminders'] == true);
  }
}
