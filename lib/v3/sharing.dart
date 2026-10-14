import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'widgets.dart';

Future<void> shareDashboard(BuildContext context, GlobalKey key) async {
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) throw StateError('No dashboard');
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('No image');
    await const MethodChannel('com.boxill/vision').invokeMethod('shareImage', {
      'base64': base64Encode(data.buffer.asUint8List()),
    });
  } catch (_) {
    if (context.mounted) {
      notice(context, 'Could not open sharing. Please try again.');
    }
  }
}
