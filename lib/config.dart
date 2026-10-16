import 'package:flutter/foundation.dart';

/// App-wide constants for EatSoon.
class AppConfig {
  static const String appName = 'EatSoon';
  static const String appSubtitle = 'Food Expiry Tracker';
  static const String bundleId = 'com.boxill.eatsoon';

  /// RevenueCat public SDK key for the EatSoon project.
  static const String iosRevenueCatApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const String androidRevenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static String get revenueCatApiKey =>
      defaultTargetPlatform == TargetPlatform.android
      ? androidRevenueCatApiKey
      : iosRevenueCatApiKey;
  static const String entitlementId = 'pro';
  static const String offeringId = 'default';

  /// Free tier limits.
  static const int freeItemLimit = 5;
  static const int defaultLeadDays = 2;

  // TODO: replace with real hosted pages before App Store submission.
  static const String termsUrl = 'https://boxillapps.com/eatsoon/terms';
  static const String privacyUrl = 'https://boxillapps.com/eatsoon/privacy';
}
