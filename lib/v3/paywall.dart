import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'brand.dart';
import 'widgets.dart';

Future<void>? _billing;
Future<void> ensureBilling() => _billing ??= (() async {
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

class V3Paywall extends StatefulWidget {
  const V3Paywall({super.key});
  @override
  State<V3Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<V3Paywall> {
  List<Package> packages = [];
  bool loading = true, busy = false;
  String? problem;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await ensureBilling();
      final offerings = await Purchases.getOfferings().timeout(
        const Duration(seconds: 12),
      );
      final list =
          (offerings.getOffering(AppConfig.offeringId) ?? offerings.current)
              ?.availablePackages ??
          [];
      if (mounted) {
        setState(() {
          packages = list;
          loading = false;
          problem = list.isEmpty ? 'Plans are unavailable right now.' : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          problem = 'Plans are unavailable right now.';
        });
      }
    }
  }

  Future<void> purchase(Package package) async {
    setState(() => busy = true);
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      if (mounted) {
        if (result
                .customerInfo
                .entitlements
                .all[AppConfig.entitlementId]
                ?.isActive ==
            true) {
          Navigator.pop(context, true);
        } else {
          notice(context, 'Purchase is pending.');
        }
      }
    } catch (_) {
      if (mounted) notice(context, 'Purchase did not complete.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    setState(() => busy = true);
    try {
      final info = await Purchases.restorePurchases();
      if (mounted) {
        if (info.entitlements.all[AppConfig.entitlementId]?.isActive == true) {
          Navigator.pop(context, true);
        } else {
          notice(context, 'No active purchase found.');
        }
      }
    } catch (_) {
      if (mounted) notice(context, 'Could not restore right now.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          MainTitle(
            '$appName Plus',
            trailing: IconButton(
              tooltip: 'Close',
              onPressed: busy ? null : () => Navigator.pop(context, false),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.workspace_premium_outlined,
                  size: 80,
                  color: accent,
                ),
                const SizedBox(height: 26),
                const Text(
                  'Keep creating with more room to grow.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (loading) const LinearProgressIndicator(),
                if (problem != null)
                  Text(problem!, textAlign: TextAlign.center),
                for (final package in packages.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: OutlinedButton(
                      onPressed: busy ? null : () => purchase(package),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                package.packageType == PackageType.annual
                                    ? 'Yearly'
                                    : package.packageType == PackageType.monthly
                                    ? 'Monthly'
                                    : package.storeProduct.title,
                              ),
                            ),
                            Text(
                              package.storeProduct.priceString,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (packages.isNotEmpty)
                  const Text(
                    'Payment is charged through Apple. Subscriptions renew automatically unless cancelled at least 24 hours before renewal. Manage or cancel in Apple account settings.',
                    style: TextStyle(fontSize: 13),
                  ),
                if (busy) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy ? null : restore,
                  child: const Text('Restore purchases'),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(AppConfig.termsUrl)),
                      child: const Text('Terms'),
                    ),
                    TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(AppConfig.privacyUrl)),
                      child: const Text('Privacy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: MainAction(
              'Continue free',
              busy ? null : () => Navigator.pop(context, false),
              icon: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    ),
  );
}
