import 'package:eatsoon/config.dart';
import 'package:eatsoon/services/revenuecat_service.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:eatsoon/theme.dart';
import 'package:eatsoon/widgets/paywall_option_card.dart';
import 'package:eatsoon/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Custom paywall: EatSoon Pro. Monthly vs yearly, free trial,
/// restore, close -> free tier.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, required this.onDone});

  /// Called when the paywall is dismissed (purchased or closed).
  final void Function(bool purchased) onDone;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<PaywallOption> _options = [];
  PaywallOption? _selected;
  bool _busy = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options =
          await ref.read(revenueCatServiceProvider).fetchOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        _selected = options.where((o) => o.bestValue).firstOrNull ??
            options.firstOrNull;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _purchase() async {
    final option = _selected;
    if (option == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok =
        await ref.read(revenueCatServiceProvider).purchase(option);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.read(isProProvider.notifier).state = true;
      widget.onDone(true);
    } else {
      setState(() => _error = 'Purchase didn\u2019t go through. Try again.');
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(revenueCatServiceProvider).restore();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.read(isProProvider.notifier).state = true;
      widget.onDone(true);
    } else {
      setState(() => _error = 'No previous purchase found.');
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: EatSoonColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => widget.onDone(false),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: EatSoonColors.tomatoTint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: EatSoonColors.tomato,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('EatSoon Pro', style: textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Unlimited items and smarter reminders, so nothing you buy goes to waste.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: EatSoonColors.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )
                    else if (_options.isEmpty)
                      const Text(
                        'Couldn\u2019t load plans. Check your connection and try again.',
                      )
                    else
                      for (final option in _options) ...[
                        PaywallOptionCard(
                          option: option,
                          selected: _selected == option,
                          onTap: () =>
                              setState(() => _selected = option),
                        ),
                        const SizedBox(height: 12),
                      ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: EatSoonColors.tomato,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: _selected == null
                          ? 'Start free trial'
                          : 'Start ${_selected!.trialText}',
                      onPressed: _selected == null ? null : _purchase,
                      isLoading: _busy,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _restore,
                      child: const Text('Restore purchases'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selected == null
                          ? 'Free trial, then the plan price. Cancel anytime in Settings.'
                          : 'Free trial, then ${_selected!.priceString}. Cancel anytime in Settings.',
                      style: textTheme.labelMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => _openUrl(AppConfig.termsUrl),
                          child: const Text(
                            'Terms',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openUrl(AppConfig.privacyUrl),
                          child: const Text(
                            'Privacy',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
