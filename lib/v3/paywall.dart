import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../config.dart';

Future<void>? _billing;
Future<void> ensureBilling() {
  if (AppConfig.revenueCatApiKey.isEmpty) {
    return Future.error(
      StateError('Subscriptions are not configured for this platform yet.'),
    );
  }
  return _billing ??= (() async {
    try {
      if (!await Purchases.isConfigured) {
        await Purchases.configure(
          PurchasesConfiguration(AppConfig.revenueCatApiKey),
        );
      }
    } catch (_) {
      _billing = null;
      rethrow;
    }
  })();
}

/// Presentation only: all purchase UI and pricing comes from RevenueCat.
Future<bool> presentProPaywall() async {
  await ensureBilling();
  final offerings = await Purchases.getOfferings();
  final offering = offerings.getOffering(AppConfig.offeringId);
  if (offering == null)
    throw StateError('The default offering is unavailable.');
  final result = await RevenueCatUI.presentPaywallIfNeeded(
    AppConfig.entitlementId,
    offering: offering,
    displayCloseButton: true,
  );
  if (result == PaywallResult.error)
    throw StateError('The remote paywall could not load.');
  final info = await Purchases.getCustomerInfo();
  return info.entitlements.active.containsKey(AppConfig.entitlementId);
}

class V3Paywall extends StatefulWidget {
  const V3Paywall({super.key, this.onComplete});
  final ValueChanged<bool>? onComplete;
  @override
  State<V3Paywall> createState() => _RemotePaywallState();
}

class _RemotePaywallState extends State<V3Paywall> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _present());
  }

  Future<void> _present() async {
    bool unlocked = false;
    String? error;
    try {
      unlocked = await presentProPaywall();
    } catch (_) {
      error = AppConfig.revenueCatApiKey.isEmpty
          ? 'Subscriptions are not available on this platform yet.'
          : 'Subscriptions could not load. Please try again later.';
    }
    if (!mounted) return;
    if (error != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    if (widget.onComplete != null) {
      widget.onComplete!(unlocked);
    } else {
      Navigator.pop(context, unlocked);
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
