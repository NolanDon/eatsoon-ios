import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'experience_preferences.dart';

const brandMotion = "sort";
bool motionReduced(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    ExperiencePreferences.instance.flag('reduceMotion', fallback: false);

/// Short purposeful entrances, with no continuous decorative loops.
Widget brandTransform(double progress, Widget child) {
  final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
  final remaining = 1 - t;
  return switch (brandMotion) {
    'breathe' => Transform.scale(scale: .94 + .06 * t, child: child),
    'sort' => Transform.translate(
      offset: Offset(0, 18 * remaining),
      child: child,
    ),
    'heat' => Transform.translate(
      offset: Offset(0, -12 * remaining),
      child: child,
    ),
    'gaze' => ClipRect(
      child: Align(widthFactor: .9 + .1 * t, child: child),
    ),
    'stitch' => Transform.translate(
      offset: Offset(10 * remaining, 4 * math.sin(t * math.pi)),
      child: child,
    ),
    'gauge' => Transform.rotate(angle: -.025 * remaining, child: child),
    'dart' => Transform.translate(
      offset: Offset(-24 * remaining, 0),
      child: child,
    ),
    'balance' => Transform.rotate(
      angle: .035 * math.sin(t * math.pi) * remaining,
      child: child,
    ),
    'grow' => Transform.scale(
      alignment: Alignment.bottomCenter,
      scale: .92 + .08 * t,
      child: child,
    ),
    'save' => Transform.translate(
      offset: Offset(0, 12 * remaining),
      child: Transform.scale(scale: .97 + .03 * t, child: child),
    ),
    _ => child,
  };
}

class BrandEntrance extends StatelessWidget {
  const BrandEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => motionReduced(context)
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(
            milliseconds: brandMotion == 'breathe' ? 700 : 420,
          ),
          child: child,
          builder: (_, value, child) =>
              Opacity(opacity: value, child: brandTransform(value, child!)),
        );
}

class BrandPageTransitions extends PageTransitionsBuilder {
  const BrandPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (motionReduced(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: brandTransform(animation.value, child!),
      ),
    );
  }
}

Widget experienceAppBuilder(BuildContext context, Widget? child) =>
    ListenableBuilder(
      listenable: ExperiencePreferences.instance,
      builder: (context, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              ExperiencePreferences.instance.flag(
                'reduceMotion',
                fallback: false,
              ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

class BrandValue extends StatelessWidget {
  const BrandValue(this.value, {super.key, this.style, this.textKey});
  final String value;
  final Key? textKey;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: motionReduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    transitionBuilder: (child, animation) => AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) => Opacity(
        opacity: animation.value,
        child: brandTransform(animation.value, child!),
      ),
    ),
    child: KeyedSubtree(
      key: ValueKey(value),
      child: Text(value, key: textKey, style: style),
    ),
  );
}
