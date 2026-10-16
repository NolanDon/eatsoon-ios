import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/v3/paywall.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('remote paywall cancellation preserves free access and requests default/pro', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    MethodCall? presentation;
    const purchases = MethodChannel('purchases_flutter');
    const ui = MethodChannel('purchases_ui_flutter');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(purchases, (call) async {
      switch (call.method) {
        case 'isConfigured': return true;
        case 'getOfferings': return {'all': {'default': {'identifier': 'default', 'serverDescription': 'Dashboard design', 'metadata': {}, 'availablePackages': []}}, 'current': null};
        case 'getCustomerInfo': return {
          'entitlements': {'all': {}, 'active': {}}, 'allPurchaseDates': {},
          'activeSubscriptions': [], 'allPurchasedProductIdentifiers': [],
          'nonSubscriptionTransactions': [], 'firstSeen': '2026-10-15T00:00:00Z',
          'originalAppUserId': 'test-user', 'allExpirationDates': {},
          'requestDate': '2026-10-15T00:00:00Z',
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(ui, (call) async { presentation = call; return 'CANCELLED'; });
    addTearDown(() { messenger.setMockMethodCallHandler(purchases, null); messenger.setMockMethodCallHandler(ui, null); });
    expect(await presentProPaywall(), false);
    expect(presentation?.method, 'presentPaywallIfNeeded');
    expect(presentation?.arguments['requiredEntitlementIdentifier'], 'pro');
    expect(presentation?.arguments['offeringIdentifier'], 'default');
  });
}
