import 'package:eatsoon/config.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// One purchasable option on the paywall. [package] is null in fakes/tests.
class PaywallOption {
  PaywallOption({
    required this.identifier,
    required this.title,
    required this.priceString,
    required this.trialText,
    required this.bestValue,
    this.package,
  });

  final String identifier;
  final String title;
  final String priceString;
  final String trialText;
  final bool bestValue;
  final Package? package;
}

/// RevenueCat facade. The UI only talks to this abstraction, which makes
/// the paywall fully testable with [FakeRevenueCatService].
abstract class RevenueCatService {
  Future<void> init();
  Future<bool> isPro();
  Future<List<PaywallOption>> fetchOptions();
  Future<bool> purchase(PaywallOption option);
  Future<bool> restore();
}

/// Production implementation backed by purchases_flutter.
class LiveRevenueCatService implements RevenueCatService {
  @override
  Future<void> init() async {
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatApiKey),
    );
  }

  bool _isProCustomer(CustomerInfo info) =>
      info.entitlements.all[AppConfig.entitlementId]?.isActive ?? false;

  @override
  Future<bool> isPro() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return _isProCustomer(info);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<PaywallOption>> fetchOptions() async {
    final offerings = await Purchases.getOfferings();
    final offering = offerings.getOffering(AppConfig.offeringId) ??
        offerings.current;
    if (offering == null) return [];
    final options = <PaywallOption>[];
    for (final package in offering.availablePackages) {
      final isAnnual = package.packageType == PackageType.annual;
      final isMonthly = package.packageType == PackageType.monthly;
      if (!isAnnual && !isMonthly) continue;
      final trial = package.storeProduct.introductoryPrice;
      options.add(PaywallOption(
        identifier: package.identifier,
        title: isAnnual ? 'Yearly' : 'Monthly',
        priceString: package.storeProduct.priceString,
        trialText: trial != null
            ? '${_trialDays(trial)}-day free trial'
            : (isAnnual ? '7-day free trial' : '3-day free trial'),
        bestValue: isAnnual,
        package: package,
      ));
    }
    options.sort((a, b) => a.bestValue ? 1 : -1);
    return options;
  }

  /// Best-effort extraction of trial length in days from the
  /// introductory price period (e.g. P3D -> 3, P1W -> 7).
  String _trialDays(IntroductoryPrice trial) {
    final period = trial.period;
    final match = RegExp(r'P(\d+)([DWM])').firstMatch(period);
    if (match == null) return '7';
    final n = int.parse(match.group(1)!);
    switch (match.group(2)) {
      case 'W':
        return '${n * 7}';
      case 'M':
        return '${n * 30}';
      default:
        return '$n';
    }
  }

  @override
  Future<bool> purchase(PaywallOption option) async {
    final package = option.package;
    if (package == null) return false;
    try {
      final result =
          await Purchases.purchase(PurchaseParams.package(package));
      return _isProCustomer(result.customerInfo);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      return _isProCustomer(info);
    } catch (_) {
      return false;
    }
  }
}

/// In-memory fake for widget tests and previews.
class FakeRevenueCatService implements RevenueCatService {
  bool _pro = false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> isPro() async => _pro;

  @override
  Future<List<PaywallOption>> fetchOptions() async => [
        PaywallOption(
          identifier: 'monthly',
          title: 'Monthly',
          priceString: '\$2.99',
          trialText: '3-day free trial',
          bestValue: false,
        ),
        PaywallOption(
          identifier: 'yearly',
          title: 'Yearly',
          priceString: '\$19.99',
          trialText: '7-day free trial',
          bestValue: true,
        ),
      ];

  @override
  Future<bool> purchase(PaywallOption option) async {
    _pro = true;
    return true;
  }

  @override
  Future<bool> restore() async => _pro;
}
