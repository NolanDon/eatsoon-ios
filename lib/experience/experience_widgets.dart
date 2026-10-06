import 'feedback_form.dart';
import 'feedback_service.dart';
import 'review_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'brand_motion.dart';
import 'experience_preferences.dart';
import 'experience_content.dart';

class PreferenceChoices extends ConsumerWidget {
  const PreferenceChoices({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: ExperiencePreferences.instance,
    builder: (context, _) {
      final prefs = ExperiencePreferences.instance;
      final selected = currentAppPreference(ref);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(preferenceTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in preferenceOptions.entries)
                ChoiceChip(
                  selectedColor: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .12),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: .15),
                  ),
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  onSelected: (value) async {
                    if (!value) return;
                    try {
                      await saveAppPreference(entry.key, ref);
                      await prefs.haptic();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not save this setting. Please try again.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ],
      );
    },
  );
}

/// Artwork sits directly on the screen color: no card, matte, or cropping.
class ExperienceOnboardingPage extends StatelessWidget {
  const ExperienceOnboardingPage({super.key, required this.setup});
  final bool setup;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            BrandEntrance(
              child: Image.asset(
                'assets/onboarding_extended/slide_${setup ? 5 : 4}.png',
                height: (constraints.maxHeight * .43).clamp(110.0, 230.0),
                width: double.infinity,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              setup ? setupTitle : workflowTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              setup ? setupBody : workflowBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            if (setup) const PreferenceChoices(),
          ],
        ),
      );
    },
  );
}

class ExperienceSettingsButton extends StatelessWidget {
  const ExperienceSettingsButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Settings',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ExperienceSettingsScreen())),
  );
}

/// Also embedded in the two apps that already have a settings screen.
class ExperienceSettingsSection extends StatelessWidget {
  const ExperienceSettingsSection({super.key});
  Future<void> _review(BuildContext context) async {
    try {
      final opened = await openAppStoreReview(appStoreId);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reviews will be available when this app is on the App Store.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The App Store could not be opened. Please try again later.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ExperiencePreferences.instance,
    builder: (context, _) {
      final prefs = ExperiencePreferences.instance;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExperienceCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: PreferenceChoices(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Comfort & feedback',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ExperienceCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Reduce motion'),
                  subtitle: const Text(
                    'Keep transitions and illustrations still.',
                  ),
                  value: prefs.flag('reduceMotion', fallback: false),
                  onChanged: (v) => prefs.setFlag('reduceMotion', v),
                ),
                SwitchListTile(
                  title: const Text('Touch feedback'),
                  subtitle: const Text(
                    'Gentle feedback when using app controls.',
                  ),
                  value: prefs.flag('haptics'),
                  onChanged: (v) => prefs.setFlag('haptics', v),
                ),
                SwitchListTile(
                  title: const Text('Occasional review requests'),
                  subtitle: const Text(
                    'Allow Apple’s rating prompt after you have used the app.',
                  ),
                  value: prefs.flag('reviewRequests'),
                  onChanged: (v) => prefs.setFlag('reviewRequests', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExperienceCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('Tips & quick setup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExperienceGuideScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About & licenses'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: appName,
                  ),
                ),
                const FeedbackForm(send: sendFeedback),
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Write an App Store review'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _review(context),
                ),
                ListTile(
                  leading: const Icon(Icons.subscriptions_outlined),
                  title: const Text('Manage subscriptions'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    final ok = await launchUrl(
                      Uri.parse('https://apps.apple.com/account/subscriptions'),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscriptions could not be opened.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class ExperienceSettingsScreen extends StatelessWidget {
  const ExperienceSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [ExperienceSettingsSection()],
    ),
  );
}

class ExperienceGuideScreen extends StatelessWidget {
  const ExperienceGuideScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tips & quick setup')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Image.asset(
          'assets/onboarding_extended/slide_4.png',
          height: 190,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: 20),
        Text(workflowTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(workflowBody, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        for (final tip in practicalTips) ...[
          ExperienceCard(
            child: Padding(padding: const EdgeInsets.all(16), child: Text(tip)),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        const PreferenceChoices(),
      ],
    ),
  );
}

class ExperienceCard extends StatelessWidget {
  const ExperienceCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .12),
      ),
    ),
    child: child,
  );
}
