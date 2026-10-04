import 'package:eatsoon/config.dart';
import 'package:eatsoon/screens/paywall_screen.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:eatsoon/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings: reminder lead time (Pro), subscription, legal links.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          onDone: (_) => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    final leadDays = ref.watch(leadDaysProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Reminders', style: textTheme.bodyLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remind me before expiry',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1 day')),
                      ButtonSegment(value: 2, label: Text('2 days')),
                      ButtonSegment(value: 3, label: Text('3 days')),
                    ],
                    selected: {leadDays},
                    onSelectionChanged: isPro
                        ? (s) => ref
                            .read(itemsProvider.notifier)
                            .setLeadDays(s.first)
                        : null,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? EatSoonColors.tomato
                            : Colors.white,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : EatSoonColors.ink,
                      ),
                    ),
                  ),
                  if (!isPro) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: EatSoonColors.inkMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Changing reminder timing is a Pro feature.',
                            style: textTheme.labelMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openPaywall(context),
                          child: const Text('Go Pro'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Subscription', style: textTheme.bodyLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                isPro ? Icons.verified : Icons.star_outline,
                color: EatSoonColors.tomato,
              ),
              title: Text(isPro ? 'EatSoon Pro active' : 'EatSoon Free'),
              subtitle: Text(
                isPro
                    ? 'Thanks for supporting EatSoon.'
                    : 'Unlimited items and smarter reminders.',
              ),
              trailing: isPro ? null : const Icon(Icons.chevron_right),
              onTap: isPro ? null : () => _openPaywall(context),
            ),
          ),
          if (isPro)
            Card(
              child: ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore purchases'),
                onTap: () async {
                  final ok = await ref
                      .read(revenueCatServiceProvider)
                      .restore();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Purchases restored.' : 'No purchases found.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          const SizedBox(height: 24),
          Text('About', style: textTheme.bodyLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Terms of Use'),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: () => _openUrl(AppConfig.termsUrl),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: () => _openUrl(AppConfig.privacyUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'EatSoon 1.0.0',
              style: textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
