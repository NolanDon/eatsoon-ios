import 'package:flutter/material.dart';

/// Generated poses use their original alpha. Entrance motion stops and respects Reduce Motion.
class Mascot extends StatelessWidget {
  final String pose;
  final double height;
  final String? label;
  const Mascot({
    super.key,
    this.pose = 'welcome',
    this.height = 120,
    this.label,
  });
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final image = Image.asset(
      'assets/v3/mascot/$pose.png',
      height: height,
      width: height * 1.15,
      fit: BoxFit.contain,
      cacheWidth: (height * 3).round(),
      excludeFromSemantics: label == null,
      semanticLabel: label,
      errorBuilder: (_, e, s) => SizedBox(height: height, width: height * 1.15),
    );
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 250),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(pose),
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        ),
        child: image,
      ),
    );
  }
}
