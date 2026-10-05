import '../experience/experience_widgets.dart';

import 'package:eatsoon/state/providers.dart';
import 'package:eatsoon/theme.dart';
import 'package:eatsoon/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Three-page onboarding: problem -> how it works -> reminders.
/// Shown once, then the paywall.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _permissionAsked = false;
  bool _permissionGranted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 4) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDone();
    }
  }

  Future<void> _askPermission() async {
    setState(() => _permissionAsked = true);
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    setState(() => _permissionGranted = granted);
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
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _Page(
                    image: 'assets/onboarding_1.webp',
                    title: "Good food shouldn't go to waste",
                    subtitle: 'Too much of what we buy ends up in the trash. EatSoon makes sure it doesn\u2019t.',
                  ),
                  const _Page(
                    image: 'assets/onboarding_2.webp',
                    title: 'Know what expires, at a glance',
                    subtitle: 'Add items as you unpack. EatSoon sorts them by urgency so you always know what\u2019s next.',
                    bullets: [
                      (Icons.add_circle_outline, 'Add groceries in seconds'),
                      (Icons.sort, 'Sorted by what expires first'),
                      (
                        Icons.notifications_outlined,
                        'Reminded before it\u2019s too late',
                      ),
                    ],
                  ),
                  _Page(
                    image: 'assets/onboarding_3.webp',
                    title: 'Never miss a date',
                    subtitle: 'A gentle reminder before food expires, so you can plan a meal instead of tossing it.',
                    permissionCta: !_permissionAsked
                        ? TextButton(
                            onPressed: _askPermission,
                            child: const Text('Enable reminders'),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _permissionGranted
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                color: _permissionGranted
                                    ? EatSoonColors.fresh
                                    : EatSoonColors.inkMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _permissionGranted
                                    ? 'Reminders on'
                                    : 'You can enable reminders in Settings',
                                style: textTheme.labelMedium,
                              ),
                            ],
                          ),
                  ),
                  const ExperienceOnboardingPage(setup: false),
                  const ExperienceOnboardingPage(setup: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? EatSoonColors.tomato
                          : EatSoonColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PrimaryButton(
                label: _page == 4 ? 'Get started' : 'Continue',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.image,
    required this.title,
    required this.subtitle,
    this.bullets = const [],
    this.permissionCta,
  });

  final String image;
  final String title;
  final String subtitle;
  final List<(IconData, String)> bullets;
  final Widget? permissionCta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(image, height: 220, fit: BoxFit.cover),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: textTheme.bodyLarge?.copyWith(
                  color: EatSoonColors.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (bullets.isNotEmpty) ...[
                const SizedBox(height: 24),
                for (final (icon, label) in bullets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(icon, color: EatSoonColors.tomato, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label, style: textTheme.bodyLarge),
                        ),
                      ],
                    ),
                  ),
              ],
              if (permissionCta != null) ...[
                const SizedBox(height: 16),
                permissionCta!,
              ],
              // Breathing room at the bottom when scrolling on small screens.
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
