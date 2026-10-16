import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// The iOS channel is retained; Android media uses supported Flutter plugins.
class AppVision {
  const AppVision();
  static const _ios = MethodChannel('com.boxill/vision');
  static bool _picking = false;
  static bool _checkedRecovery = false;
  static XFile? _recoveredPhoto;
  Future<void> _recoverCameraResult() async {
    if (_checkedRecovery) return;
    _checkedRecovery = true;
    final lost = await ImagePicker().retrieveLostData();
    if (lost.files?.isNotEmpty == true) _recoveredPhoto = lost.files!.first;
  }
  Future<Directory> get _folder async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/V3Media').create(recursive: true);
  }

  Future<File> _file(String name) async {
    if (!RegExp(r'^[A-Za-z0-9-]+\.(jpg|png)$').hasMatch(name)) {
      throw PlatformException(code: 'image', message: 'Invalid photo.');
    }
    return File('${(await _folder).path}/$name');
  }

  Future<Map<String, dynamic>> _save(Uint8List bytes) async {
    final source = img.decodeImage(bytes);
    if (source == null)
      throw PlatformException(
        code: 'image',
        message: 'Choose a supported photo.',
      );
    final upright = img.bakeOrientation(source);
    if (upright.width < 256 || upright.height < 256) {
      throw PlatformException(code: 'image', message: 'Choose a larger photo.');
    }
    final resized = upright.width <= 1200 && upright.height <= 1200
        ? upright
        : img.copyResize(
            upright,
            width: upright.width >= upright.height ? 1200 : null,
            height: upright.height > upright.width ? 1200 : null,
          );
    final jpeg = img.encodeJpg(resized, quality: 78);
    final file = await _file('${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(jpeg);
    return {'file': file.uri.pathSegments.last, 'base64': base64Encode(jpeg)};
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    if (!Platform.isAndroid) return _ios.invokeMethod<T>(method, arguments);
    final args = Map<String, dynamic>.from(arguments as Map? ?? {});
    dynamic value;
    switch (method) {
      case 'directory':
        await _recoverCameraResult();
        value = (await _folder).path;
      case 'capture':
      case 'pick':
        if (_picking)
          throw PlatformException(
            code: 'busy',
            message: 'Finish the current photo first.',
          );
        _picking = true;
        try {
          await _recoverCameraResult();
          final recovered = _recoveredPhoto;
          _recoveredPhoto = null;
          final photo = recovered ?? await ImagePicker().pickImage(
            source: method == 'capture'
                ? ImageSource.camera
                : ImageSource.gallery,
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 85,
          );
          value = photo == null ? null : await _save(await photo.readAsBytes());
        } finally {
          _picking = false;
        }
      case 'processPhoto':
        value = await _save(base64Decode(args['base64'] as String));
      case 'saveArtwork':
        final bytes = base64Decode(args['base64'] as String);
        final saved = await _save(bytes);
        value = saved['file'];
      case 'removePhoto':
        final file = await _file(args['file'] as String);
        if (await file.exists()) await file.delete();
        value = true;
      case 'transferPhoto':
        value = base64Encode(
          await (await _file(args['file'] as String)).readAsBytes(),
        );
      case 'transferQr':
        final data = await QrPainter(
          data: args['text'] as String,
          version: QrVersions.auto,
          gapless: true,
          color: const ui.Color(0xFF000000),
          emptyColor: const ui.Color(0xFFFFFFFF),
        ).toImageData(512, format: ui.ImageByteFormat.png);
        value = data == null ? null : base64Encode(data.buffer.asUint8List());
      case 'readTransferQr':
        final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
        try {
          final codes = await scanner.processImage(
            InputImage.fromFilePath((await _file(args['file'] as String)).path),
          );
          value = codes.isEmpty ? null : codes.first.rawValue;
        } finally {
          await scanner.close();
        }
      case 'shareTransfer':
        final result = await SharePlus.instance.share(
          ShareParams(text: args['text'] as String),
        );
        value = result.status == ShareResultStatus.success;
      case 'shareImage':
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                base64Decode(args['base64'] as String),
                mimeType: 'image/png',
                name: 'creation.png',
              ),
            ],
          ),
        );
        value = result.status == ShareResultStatus.success;
      case 'cutout':
        value = await const MethodChannel('com.boxill/android_media')
            .invokeMethod<String>('cutout', args);
      case 'reminderPermission':
      case 'setReminder':
      case 'clearReminder':
        value = await const MethodChannel('com.boxill/android_media')
            .invokeMethod(method, args);
      default:
        throw MissingPluginException(
          'Unsupported Android media operation: $method',
        );
    }
    return value as T?;
  }

  Future<Map<K, V>?> invokeMapMethod<K, V>(
    String method, [
    dynamic arguments,
  ]) async {
    final value = await invokeMethod<Map>(method, arguments);
    return value?.cast<K, V>();
  }
}
