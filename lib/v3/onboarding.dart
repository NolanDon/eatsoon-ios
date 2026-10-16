import '../experience/brand_motion.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'photo_flow.dart' show vision;

import 'brand.dart';
import 'widgets.dart';

const photoInstruction =
    "Photograph your open fridge or food packages with readable labels.";
String get addTitle => switch (appKind) {
  'wrapping' => 'Plan a gift wrap',
  'mending' => 'Start a garment repair',
  'drawing' => 'Make a comic',
  'goal' => 'Start a savings goal',
  _ => 'Add to $appName',
};

class IntroStep {
  final String title, body, example;
  final IconData icon;
  const IntroStep(this.title, this.body, this.example, this.icon);
}

List<IntroStep> get _coreIntroSteps => switch (appKind) {
  'clothing' => const [
    IntroStep(
      'Your clothes, together',
      'Photograph each clothing item to build your digital wardrobe. Wearloom suggests outfits from the pieces you own.',
      'Sweater + jeans',
      Icons.checkroom,
    ),
    IntroStep(
      'One piece per photo',
      'Lay one garment flat and photograph it straight on. Include the full item and leave space around its edges.',
      'Full item in frame',
      Icons.crop_free,
    ),
    IntroStep(
      'A clean cutout',
      'Wearloom removes the background and suggests a name, color and category. Review the details before saving.',
      'Photo → wardrobe',
      Icons.auto_fix_high,
    ),
    IntroStep(
      'Shoes face forward',
      'Place a matching pair upright, side by side, with both toes facing you. Sideways, overlapping or cropped shoes need another photo.',
      'Both shoes visible',
      Icons.photo_camera,
    ),
    IntroStep(
      'Generate an outfit from your wardrobe',
      'Add a top and bottoms, then tap Generate outfit. Wearloom combines your pieces for the occasion you choose.',
      'Everyday · smart · active',
      Icons.style,
    ),
    IntroStep(
      'Save the outfits you love',
      'Try another combination or save one you like. Your wardrobe and saved outfits stay on this device.',
      'Try again → save',
      Icons.bookmark_border,
    ),
    IntroStep(
      'Try it with your clothes',
      'Photograph a whole garment in bright, even light, or choose an existing photo. Each picture becomes a piece in your wardrobe.',
      'Ready for your first piece',
      Icons.kitchen_outlined,
    ),
  ],
  'plant' => const [
    IntroStep(
      "Turn a plant photo into a care plan",
      "Tendly suggests a likely plant name and a soil-check rhythm. Review the draft before saving.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Frame the leaves and the pot",
      "Photograph one whole houseplant in daylight. Keep the leaves sharp and the pot in view.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Save, check soil, then record care",
      "Your plant appears on your dashboard. Check the soil before watering, then record what you did.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'meal' => const [
    IntroStep(
      "Turn your meal into a recipe draft",
      "ScaleRecipe suggests ingredients and cooking steps from a meal photo. Review the estimates before cooking.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Photograph the whole cooked meal",
      "Use a clear, well-lit photo of prepared food. Keep the full plate in view and skip blurry pictures.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Save a recipe and change servings",
      "Choose how many people you are cooking for. Ingredient quantities scale with your serving count.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'fridge' => const [
    IntroStep(
      "Turn a fridge photo into a food list",
      "EatSoon drafts a list of visible food so you can use it sooner. Review each item and its dates.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Show the food and face labels forward",
      "Photograph your open fridge or several food packages in good light. Include readable date labels when possible.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Save the list and mark food used",
      "Your dashboard puts upcoming checks first. Dates are reminders to check labels, not food-safety guarantees.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'knitting' => const [
    IntroStep(
      "Turn a pattern photo into a row guide",
      "KnitTally helps you follow a written knitting pattern or stitch chart. Review the detected rows before starting.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Photograph readable rows or a close-up stitch",
      "Keep the chart symbols or written instructions sharp and flat. A fabric photo can suggest a stitch, but cannot reveal a complete pattern.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Follow a row and keep your place",
      "Work through the saved instructions and advance your row. Your progress stays ready for the next session.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'goal' => const [
    IntroStep(
      "Turn your next purchase into a savings goal",
      "Weekstash helps you save for one specific thing. Choose a product listing with a visible price or enter your target.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Photograph a written goal or product screenshot",
      "Write your goal on paper and take a photo, or use a clear product screenshot with its price. Check the amount before saving.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Record savings and watch your progress",
      "Add only money you actually set aside. Your goal fills as you record contributions.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'maintenance' => const [
    IntroStep(
      "Turn a receipt into a service record",
      "Odoly keeps a vehicle service history you can review. It reads visible tasks, dates and mileage without diagnosing repairs.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Photograph a readable service receipt",
      "Keep the whole receipt flat and its text sharp. An odometer photo also works when the mileage and unit are visible.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Save the service and revisit the history",
      "Check the extracted details and add missing information. Your dashboard keeps the record with your vehicle.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'drawing' => const [
    IntroStep(
      "Turn your drawing into a four-scene comic",
      "Doodlebook redraws your character in four new illustrated scenes. You can edit every caption after opening the comic.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Photograph one drawing, flat and clear",
      "Use an original doodle on paper in even light. Keep the character visible and avoid glare or blurred lines.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Open your comic, edit it, and share",
      "Your new comic appears on the same bookshelf as your saved comics. Open it to read the scenes and change their captions.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'wrapping' => const [
    IntroStep(
      "Turn an awkward gift into a wrapping plan",
      "Foldora chooses a practical wrapping method for the shape you show. Follow a folding guide using supplies you already have.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Photograph the unwrapped gift",
      "Show one whole object on a plain surface. Keep every edge in frame; a photo cannot determine its exact measurements.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Follow the folds and share the finished gift",
      "Review the method, gather paper or cloth, and follow each step. Save your progress and share the wrapping plan.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  'mending' => const [
    IntroStep(
      "Turn a small tear into a repair project",
      "Patchling helps you plan a visible patch, seam repair or button replacement. Keep the garment and record your progress.",
      "",
      Icons.fact_check_outlined,
    ),
    IntroStep(
      "Photograph the damage close up",
      "Lay the garment flat in good light. Show the tear and surrounding fabric; do not photograph an injury or skin.",
      "",
      Icons.inventory_2_outlined,
    ),
    IntroStep(
      "Follow the stitches and save your mend",
      "Check the suggested technique and supplies before starting. Follow one step at a time and share your repair plan.",
      "",
      Icons.kitchen_outlined,
    ),
  ],
  _ => const [],
};

const needsReminderIntro =
    appKind == 'plant' ||
    appKind == 'fridge' ||
    appKind == 'goal' ||
    appKind == 'maintenance';
List<IntroStep> get introSteps => [
  ..._coreIntroSteps,
  if (needsReminderIntro)
    const IntroStep(
      'Let a gentle reminder help',
      'Allow notifications for the dates you save. You can skip this and still use every tool.',
      '',
      Icons.notifications_outlined,
    ),
];

class FeatureOnboarding extends StatefulWidget {
  final VoidCallback onDone;
  const FeatureOnboarding({super.key, required this.onDone});
  @override
  State<FeatureOnboarding> createState() => _FeatureOnboardingState();
}

class _FeatureOnboardingState extends State<FeatureOnboarding> {
  int index = 0;
  bool enabling = false;
  Future<void> allowReminders() async {
    if (enabling) return;
    setState(() => enabling = true);
    try {
      final granted =
          await vision.invokeMethod<bool>('reminderPermission') ?? false;
      if (granted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('v3.$appId.reminders', true);
      }
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Notifications are unavailable. You can enable them later in Settings.',
        );
      }
    }
    if (mounted) widget.onDone();
  }

  double textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    final steps = introSteps, step = steps[index];
    final titleStyle = Theme.of(context).textTheme.headlineLarge!
        .copyWith(fontSize: 28);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge!
        .copyWith(color: Color.lerp(ink, paper, .07));
    final counterStyle = Theme.of(context).textTheme.labelMedium!;
    return Column(
      children: [
        MainTitle(
          appName,
          centered: true,
          onBack: index == 0 ? null : () => setState(() => index--),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 48).clamp(
                1.0,
                double.infinity,
              );
              final wordsHeight =
                  textHeight(context, step.title, titleStyle, width) +
                  (appKind == 'drawing'
                      ? 0
                      : 12 + textHeight(context, step.body, bodyStyle, width)) +
                  textHeight(
                    context,
                    '${index + 1} of ${steps.length}',
                    counterStyle,
                    width,
                  );
              final demoHeight = (constraints.maxHeight - wordsHeight - 68)
                  .clamp(120.0, 340.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: BrandEntrance(
                  key: ValueKey(index),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Step ${index + 1} of ${steps.length}',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            steps.length,
                            (i) => AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                              width: i == index ? 44 : 16,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: ink.withValues(
                                  alpha: i == index ? .9 : .22,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FeatureDemo(
                        kind: appKind,
                        index: index,
                        step: step,
                        height: demoHeight,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        step.title,
                        style: titleStyle,
                        textAlign: TextAlign.center,
                      ),
                      if (appKind != 'drawing') ...[
                        const SizedBox(height: 12),
                        Text(
                          step.body,
                          style: bodyStyle,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (needsReminderIntro && index == steps.length - 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: enabling ? null : widget.onDone,
                child: const Text('Skip'),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: MainAction(
            needsReminderIntro && index == steps.length - 1
                ? 'Allow notifications'
                : index == 0
                ? 'Open my kitchen'
                : index == steps.length - 1
                ? 'Stock my fridge'
                : 'See how it works',
            enabling
                ? null
                : needsReminderIntro && index == steps.length - 1
                ? allowReminders
                : () => index == steps.length - 1
                      ? widget.onDone()
                      : setState(() => index++),
            icon: Icons.arrow_forward,
          ),
        ),
      ],
    );
  }
}

class FeatureDemo extends StatelessWidget {
  final String kind;
  final int index;
  final IntroStep step;
  final double height;
  const FeatureDemo({
    super.key,
    required this.kind,
    required this.index,
    required this.step,
    this.height = 300,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 300,
        height: 300,
        child: Center(
          child: needsReminderIntro && index == 3
              ? Image.asset(
                  'assets/v3/demos/notifications.png',
                  height: 275,
                  fit: BoxFit.contain,
                )
              : index == 2
              ? const _SaveDemo()
              : kind == 'clothing'
              ? _ClothingDemo(index: index)
              : kind == 'goal' && index == 1
              ? const _GoalPhotoDemo()
              : _CoreDemo(index: index),
        ),
      ),
    ),
  );
}

class _SaveDemo extends StatefulWidget {
  const _SaveDemo();
  @override
  State<_SaveDemo> createState() => _SaveDemoState();
}

class _SaveDemoState extends State<_SaveDemo> {
  bool saved = false;
  late final Timer _saveTimer;
  @override
  void initState() {
    super.initState();
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => saved = true);
    });
  }

  @override
  void dispose() {
    _saveTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Image.asset('assets/v3/demos/save.png', fit: BoxFit.contain),
      ),
      AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: saved ? ink : paper,
          border: Border.all(color: ink, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Row(
            key: ValueKey(saved),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saved) ...[
                const Icon(Icons.check, size: 17, color: paper),
                const SizedBox(width: 6),
              ],
              Text(
                saved ? 'Saved' : 'Save',
                style: TextStyle(
                  fontFamily: brandFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: saved ? paper : ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _CoreDemo extends StatelessWidget {
  final int index;
  const _CoreDemo({required this.index});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(index),
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 1600),
    builder: (context, t, child) => Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: .92 + .08 * t,
          child: Image.asset(
            index == 0
                ? 'assets/v3/demos/core.png'
                : 'assets/v3/demos/subject.png',
            height: 270,
            fit: BoxFit.contain,
          ),
        ),
        if (index == 1)
          SizedBox(
            width: 260,
            height: 245,
            child: CustomPaint(painter: _CameraFrame(t)),
          ),
        if (index == 2)
          Positioned(
            bottom: 12,
            right: 25,
            child: Transform.scale(
              scale: t,
              child: CustomPaint(
                size: const Size(56, 56),
                painter: _SavedMark(),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CameraFrame extends CustomPainter {
  final double t;
  _CameraFrame(this.t);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = ink.withValues(alpha: .7)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    for (final corner in [
      Offset.zero,
      Offset(s.width, 0),
      Offset(0, s.height),
      Offset(s.width, s.height),
    ]) {
      final dx = corner.dx == 0 ? 1.0 : -1.0, dy = corner.dy == 0 ? 1.0 : -1.0;
      c.drawPath(
        Path()
          ..moveTo(corner.dx + dx * 28, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy * 28),
        p,
      );
    }
    c.drawLine(
      Offset(10, s.height * t),
      Offset(s.width - 10, s.height * t),
      Paint()
        ..color = accent.withValues(alpha: .6)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CameraFrame old) => old.t != t;
}

class _SavedMark extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawCircle(s.center(Offset.zero), s.width / 2, Paint()..color = ink);
    c.drawPath(
      Path()
        ..moveTo(14, 28)
        ..lineTo(24, 38)
        ..lineTo(42, 18),
      Paint()
        ..color = paper
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SavedMark old) => false;
}

class _ClothingDemo extends StatelessWidget {
  final int index;
  const _ClothingDemo({required this.index});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(index),
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 2400),
    builder: (context, t, child) {
      if (index == 0) {
        return const _FloatingWardrobe();
      }
      if (index == 6) {
        return const _ClothingCaptureSequence();
      }
      final outfit = index == 4 || index == 5;
      if (outfit) {
        return SizedBox(
          width: 230,
          height: 300,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 28,
                width: 174,
                height: 122,
                child: Transform.translate(
                  offset: Offset(0, -25 * (1 - t.clamp(0, .33) / .33)),
                  child: Opacity(
                    opacity: (t / .33).clamp(0, 1),
                    child: Image.asset(
                      'assets/v3/demos/sweater.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 119,
                left: 50,
                width: 130,
                height: 145,
                child: Opacity(
                  opacity: ((t - .33) / .33).clamp(0, 1),
                  child: Image.asset(
                    'assets/v3/demos/jeans.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                top: 264,
                left: 75,
                width: 80,
                height: 36,
                child: Opacity(
                  opacity: ((t - .66) / .34).clamp(0, 1),
                  child: Image.asset(
                    'assets/v3/demos/boots-guide.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (index == 5)
                Positioned(
                  right: 0,
                  top: 20,
                  child: Transform.scale(
                    scale: ((t - .65) / .35).clamp(0, 1),
                    child: CustomPaint(
                      size: const Size(56, 56),
                      painter: _SavedMark(),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/v3/demos/${index == 3
                ? 'boots-guide'
                : index == 2
                ? 'jeans'
                : 'sweater'}.png',
            width: 245,
            height: 245,
            fit: BoxFit.contain,
          ),
          SizedBox(
            width: 270,
            height: 265,
            child: CustomPaint(painter: _CameraFrame(t)),
          ),
          if (t > .85 && t < .98)
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: .45)),
            ),
        ],
      );
    },
  );
}

class _ClothingCaptureSequence extends StatelessWidget {
  const _ClothingCaptureSequence();
  static const pieces = [
    'sweater',
    'jeans',
    'boots-guide',
    'shirt',
    'hat',
    'bag',
  ];
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 6),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(seconds: 18),
    builder: (context, t, _) {
      final index = t.floor().clamp(0, 5), phase = t >= 6 ? .6 : t - t.floor();
      final arrival = (phase / .24).clamp(0.0, 1.0),
          exit = ((phase - .8) / .2).clamp(0.0, 1.0);
      return Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(300 * (1 - Curves.easeOut.transform(arrival)), 0),
            child: Opacity(
              opacity: 1 - exit,
              child: Image.asset(
                'assets/v3/demos/${pieces[index]}.png',
                width: 240,
                height: 240,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(
            width: 270,
            height: 265,
            child: CustomPaint(
              painter: _CameraFrame(((phase - .25) / .45).clamp(0.0, 1.0)),
            ),
          ),
          if (phase > .7 && phase < .78)
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: .65)),
            ),
        ],
      );
    },
  );
}

class _GoalPhotoDemo extends StatelessWidget {
  const _GoalPhotoDemo();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(seconds: 12),
    builder: (context, t, _) {
      const goal = 'Save 50k for house down payment';
      final paperVisible = t >= .35;
      final letters = (((t - .4) / .35).clamp(0.0, 1.0) * goal.length).floor();
      return Stack(
        alignment: Alignment.center,
        children: [
          if (!paperVisible)
            Image.asset(
              'assets/v3/demos/subject.png',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
          if (paperVisible)
            Transform.rotate(
              angle: -.04,
              child: Container(
                width: 238,
                height: 225,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCED),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: ink.withValues(alpha: .15),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    goal.substring(0, letters),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Goal Handwriting',
                      fontSize: 32,
                      color: ink,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 270,
            height: 265,
            child: CustomPaint(
              painter: _CameraFrame(
                paperVisible
                    ? ((t - .75) / .15).clamp(0.0, 1.0)
                    : (t / .3).clamp(0.0, 1.0),
              ),
            ),
          ),
          if ((t > .28 && t < .32) || (t > .9 && t < .94))
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: .65)),
            ),
        ],
      );
    },
  );
}

class _FloatingWardrobe extends StatelessWidget {
  const _FloatingWardrobe();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(seconds: 8),
    builder: (context, t, _) {
      const names = ['sweater', 'jeans', 'boots-guide', 'shirt', 'hat', 'bag'];
      const positions = [
        Rect.fromLTWH(8, 20, 105, 125),
        Rect.fromLTWH(185, 6, 100, 155),
        Rect.fromLTWH(10, 190, 85, 70),
        Rect.fromLTWH(112, 182, 90, 105),
        Rect.fromLTWH(209, 190, 88, 65),
        Rect.fromLTWH(109, 34, 72, 95),
      ];
      return SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          children: [
            for (var i = 0; i < names.length; i++)
              Positioned.fromRect(
                rect: positions[i],
                child: Transform.translate(
                  offset: Offset(
                    0,
                    5 * math.sin(t * math.pi * 4 + i) * math.sin(t * math.pi),
                  ),
                  child: Transform.rotate(
                    angle: (i.isEven ? -.08 : .09),
                    child: Image.asset(
                      'assets/v3/demos/${names[i]}.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
