/// App-wide constants for EatSoon.
class AppConfig {
  static const String appName = 'EatSoon';
  static const String appSubtitle = 'Food Expiry Tracker';
  static const String bundleId = 'com.boxill.eatsoon';

  /// RevenueCat public SDK key for the EatSoon project.
  static const String revenueCatApiKey = 'test_XtSBciyGgMeqaoxuTXMzHSHLcWL';
  static const String entitlementId = 'pro';
  static const String offeringId = 'default';

  /// Free tier limits.
  static const int freeItemLimit = 5;
  static const int defaultLeadDays = 2;

  // TODO: replace with real hosted pages before App Store submission.
  static const String termsUrl = 'https://example.com/eatsoon/terms';
  static const String privacyUrl = 'https://example.com/eatsoon/privacy';
}
