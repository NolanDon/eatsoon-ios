import '../experience/brand_motion.dart';
import '../platform/app_vision.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../niche/ai_client.dart';
import 'brand.dart';
import 'model.dart';
import 'widgets.dart';

const vision = AppVision();
Future<List<Item>?> readPhoto(
  BuildContext context,
  String directory, {
  required String source,
}) async {
  Map<String, dynamic>? photo;
  try {
    final raw = await vision.invokeMethod(
      source == 'camera' ? 'capture' : 'pick',
      {'kind': appKind},
    );
    if (raw == null || !context.mounted) return null;
    photo = Map<String, dynamic>.from(raw as Map);
    if (appKind == 'ticket') {
      final original = photo['file'];
      photo = Map<String, dynamic>.from(
        await vision.invokeMethod('redactTicket', {'file': original}) as Map,
      );
      await vision.invokeMethod('removePhoto', {'file': original});
    }
    if (!context.mounted) {
      await vision.invokeMethod('removePhoto', {'file': photo['file']});
      return null;
    }
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Check this food photo?',
                style: Theme.of(sheet).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BrandEntrance(
                  child: Photo(
                    photo!['file'] as String,
                    directory,
                    height: 220,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Send this food photo to Google Gemini to list visible items. Check names and dates before adding.',
              ),
              const SizedBox(height: 22),
              MainAction(
                'Find food',
                () => Navigator.pop(sheet, true),
                icon: Icons.auto_awesome_outlined,
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: const Text('Choose another'),
              ),
            ],
          ),
        ),
      ),
    );
    if (approved != true || !context.mounted) {
      await vision.invokeMethod('removePhoto', {'file': photo['file']});
      return null;
    }
    final response = await AiClient(apiAppId).request('/api/mobile/vision', {
      'app': apiAppId,
      'image': {'mimeType': 'image/jpeg', 'base64': photo['base64']},
      'today': day(DateTime.now()),
    });
    if (response['accepted'] != true) {
      final text = switch (response['reason']) {
        'blurred' => 'This photo is too blurry. Try a clearer one.',
        'bad_angle' => 'Place a matching pair of shoes upright, side by side and facing you, then retake the photo.',
        'multiple_garments' => 'Photograph one item at a time.',
        'unreadable' => 'The details are unclear. Try a closer photo.',
        _ => 'That photo does not match this feature.',
      };
      throw FormatException(text);
    }
    need(
      response['items'] is List && (response['items'] as List).isNotEmpty,
      'No draft found.',
    );
    final items = (response['items'] as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    need(items.length <= (appKind == 'fridge' ? 20 : 1), 'Unexpected draft.');
    for (final item in items) {
      item['photo'] = photo['file'];
      item['created'] = day(DateTime.now());
      if (appKind == 'clothing') {
        final box = (item['box'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        item['cutout'] = await vision.invokeMethod<String>('cutout', {
          'file': photo['file'],
          'box': box,
        });
        item.remove('box');
      }
      if (appKind == 'fridge' || appKind == 'plant') {
        item['nextDate'] =
            item['labelDate'] ??
            day(
              DateTime.now().add(
                Duration(days: (item['checkDays'] as num).toInt()),
              ),
            );
      }
      if (appKind == 'goal') item['saved'] = 0;
      if (appKind == 'knitting') {
        item['row'] = 0;
        item['stitchesDone'] = 0;
      }
    }
    return items;
  } on PlatformException catch (e) {
    if (photo != null) {
      try {
        await vision.invokeMethod('removePhoto', {'file': photo['file']});
      } catch (_) {}
    }
    if (context.mounted) notice(context, photoError(e));
    return null;
  } catch (e) {
    if (photo != null) {
      try {
        await vision.invokeMethod('removePhoto', {'file': photo['file']});
      } catch (_) {}
    }
    if (context.mounted) {
      notice(
        context,
        e is FormatException
            ? e.message
            : e is CompanionException
            ? e.message
            : 'Could not analyze this photo. Try again or enter the details manually.',
      );
    }
    return null;
  }
}

String photoError(PlatformException error) => switch (error.code) {
  'cutout' || 'crop' => 'Could not remove the background. Lay the item flat on a plain surface and try again, or enter it manually.',
  'busy' => 'Finish the open camera or photo picker, then try again.',
  'permission' =>
    'Camera access is off. Allow it in device Settings or choose a photo.',
  'photo' || 'image' =>
    'Choose a clear photo with the full subject visible and even lighting.',
  _ => 'Camera unavailable. Choose a photo or enter the details manually.',
};
