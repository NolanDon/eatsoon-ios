import 'package:flutter/material.dart';

import 'brand.dart';
import 'widgets.dart';

// Seven short, app-specific demonstrations precede the camera and plan choice.
class IntroStep {
  final String title, body, result;
  final IconData icon;
  const IntroStep(this.title, this.body, this.result, this.icon);
}

String get addTitle => switch (appKind) {
  'clothing' => 'Add a wardrobe item',
  'fridge' => 'Add food to track',
  'plant' => 'Add a houseplant',
  'meal' => 'Create a recipe',
  'knitting' => 'Add a knitting project',
  'furniture' => 'Check furniture fit',
  'drawing' => 'Turn your doodle into a comic',
  'ticket' => 'Save an event ticket',
  'maintenance' => 'Record a vehicle service',
  'goal' => 'Set a savings goal',
  _ => 'Add an item',
};
String get photoInstruction => switch (appKind) {
  'clothing' => 'Photograph one sweater, shirt or pair of pants laid flat, with the whole item visible. For shoes, place a matching pair upright, side by side and facing the camera.',
  'fridge' => 'Photograph the inside of your fridge or a few food packages with labels facing you. Keep items visible and review every detected item and date.',
  'plant' => 'Photograph one houseplant with its leaves and pot clearly visible. Use daylight and avoid a dark or distant shot.',
  'meal' => 'Photograph a prepared meal with the whole plate in focus. The recipe will be an approximation you can edit.',
  'knitting' => 'Photograph a readable knitting pattern or stitch chart straight on, or take a close-up of knitted fabric. Exact counts need a written pattern; fabric gives a suggested stitch guide.',
  'furniture' => 'Photograph furniture or upload a furniture listing with printed measurements. If dimensions are missing, measure the item and doorway yourself.',
  'drawing' => 'Photograph your own doodle on paper, straight on and in good light. Fill the frame with your drawing, not the app mascot or a photo of a real object.',
  'ticket' => 'Photograph an event ticket or upload a booking screenshot with the event name and date visible. Barcodes are covered on your device before analysis.',
  'maintenance' => 'Photograph a vehicle service receipt, maintenance note or a readable odometer. Keep printed mileage, units and dates in focus.',
  'goal' => 'Upload a screenshot of something you want to save for, such as a bike listing with its price. You can also photograph a written savings goal or enter the amount yourself.',
  _ => '',
};
List<IntroStep> get introSteps => switch (appKind) {
  'clothing' => const [
    IntroStep(
      'Your clothes, together',
      'Keep a visual wardrobe of pieces you already own. Start with a top and a pair of bottoms.',
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
      'Build an outfit',
      'Add a top and bottoms before generating an outfit. Color and occasion help choose pieces from your wardrobe.',
      'Everyday · smart · active',
      Icons.style,
    ),
    IntroStep(
      'Keep the combinations',
      'Try another combination or save one you like. Your wardrobe and saved outfits stay on this device.',
      'Try again → save',
      Icons.bookmark_border,
    ),
    IntroStep(
      'Try it with your clothes',
      'Photograph a sweater or pair of pants in bright, even light. You can choose a photo or enter an item manually instead.',
      'Ready for your first piece',
      Icons.camera_alt_outlined,
    ),
  ],
  'meal' => const [
    IntroStep(
      'Recreate a meal',
      'Turn a clear meal photo into a recipe to try. AI suggests ingredients and steps; it cannot recover the original recipe exactly.',
      'Meal → recipe',
      Icons.restaurant,
    ),
    IntroStep(
      'Show the whole plate',
      'Photograph prepared food in good light, with the plate in focus. Non-food and blurry photos are rejected.',
      'Prepared food in focus',
      Icons.crop_free,
    ),
    IntroStep(
      'Review the draft',
      'Check the suggested ingredients and quantities before saving. Add anything you know was in the meal.',
      'Ingredients + steps',
      Icons.edit_outlined,
    ),
    IntroStep(
      'Change the servings',
      'Choose how many people you are cooking for. Ingredient quantities scale from your saved base recipe.',
      '2 servings → 4 servings',
      Icons.people_outline,
    ),
    IntroStep(
      'Cook one step at a time',
      'Open the cooking view and follow each instruction. You can edit any step to match your own method.',
      'Step 1 → step 2',
      Icons.menu_book_outlined,
    ),
    IntroStep(
      'Keep your favorites',
      'Save recipes with their photos for another day. You can also enter a recipe with a short ingredient list.',
      'Your recipe collection',
      Icons.bookmark_border,
    ),
    IntroStep(
      'Start with a meal photo',
      'Take a photo of a cooked meal or choose one from your library. Review your first recipe before choosing a plan.',
      'Photograph a prepared meal',
      Icons.camera_alt_outlined,
    ),
  ],
  'goal' => const [
    IntroStep(
      'Give your savings a goal',
      'Choose something specific to save for, such as a bike or a trip. Weekstash tracks your progress toward that amount.',
      'Bike · goal 500',
      Icons.flag_outlined,
    ),
    IntroStep(
      'Start with the thing you want',
      'Use a product screenshot with its price or a written savings goal. A random photo cannot tell us your target amount.',
      'Item + printed price',
      Icons.photo_outlined,
    ),
    IntroStep(
      'Set the amount yourself',
      'Review the target and currency. If no price is visible, enter the amount you want to save.',
      'Target · currency · date',
      Icons.edit_outlined,
    ),
    IntroStep(
      'Record real savings',
      'Add money you have actually set aside. The jar grows as you record contributions.',
      'Saved 50 / 500',
      Icons.savings_outlined,
    ),
    IntroStep(
      'Plan a payday',
      'Enter a payday date and an amount to allocate across goals. A plan does not count as money already saved.',
      'Payday → goals',
      Icons.calendar_month,
    ),
    IntroStep(
      'Keep currencies separate',
      'Each goal keeps its own currency. Undo a mistaken contribution or remove an outdated plan.',
      'Your totals stay clear',
      Icons.undo,
    ),
    IntroStep(
      'Make your first goal',
      'Choose a product listing, travel goal or savings note. Manual entry is just as useful if you already know your target.',
      'Photograph your savings goal',
      Icons.camera_alt_outlined,
    ),
  ],
  'furniture' => const [
    IntroStep(
      'Will it fit through?',
      'Check furniture against a doorway before moving it. Fitway compares the item with a clear rectangular opening.',
      'Furniture → doorway',
      Icons.door_front_door,
    ),
    IntroStep(
      'Start with furniture',
      'Photograph the item or choose a furniture listing screenshot. Printed dimensions can be copied into your draft.',
      'Chair · sofa · cabinet',
      Icons.chair_outlined,
    ),
    IntroStep(
      'Measure what is missing',
      'A photo cannot reliably tell us exact dimensions. Measure the item width, depth and height if they are not printed.',
      'Width × depth × height',
      Icons.straighten,
    ),
    IntroStep(
      'Measure the clear opening',
      'Measure the space available inside the doorframe. Enter its usable width and height, not the outside trim.',
      'Clear doorway dimensions',
      Icons.door_sliding_outlined,
    ),
    IntroStep(
      'Try a different angle',
      'Rotate the furniture cross-section to compare clearance. The preview helps you understand why an angle works or fails.',
      'Rotate → compare',
      Icons.rotate_right,
    ),
    IntroStep(
      'Check the whole route',
      'Stairs, handles, corners and room to turn still matter. Save multiple items to compare their doorway checks.',
      'Doorway check, then route',
      Icons.route_outlined,
    ),
    IntroStep(
      'Bring a listing or photo',
      'Use a furniture photo or a listing with readable measurements. You can enter all measured sizes manually instead.',
      'Photograph furniture',
      Icons.camera_alt_outlined,
    ),
  ],
  'knitting' => const [
    IntroStep(
      'Keep your place',
      'Save knitting projects and follow a row at a time. Your counter helps you return to the right spot.',
      'Pattern → row guide',
      Icons.grid_on,
    ),
    IntroStep(
      'Show a readable pattern',
      'Photograph a written knitting pattern or stitch chart straight on. A close-up of knitted fabric can suggest a basic stitch.',
      'Pattern paper or knitted fabric',
      Icons.photo_outlined,
    ),
    IntroStep(
      'Check the suggested rows',
      'Review the instructions before saving. A fabric photo cannot reveal an exact full pattern or stitch count.',
      'Review every row',
      Icons.edit_outlined,
    ),
    IntroStep(
      'Learn the symbols',
      'The visual guide illustrates supported knit, purl, yarn-over and decrease symbols. Unclear symbols remain unknown.',
      'K · P · YO · K2TOG',
      Icons.gesture,
    ),
    IntroStep(
      'Count as you knit',
      'Tap to record progress through a row. Use undo if you counted a stitch by mistake.',
      'Stitch → row → next',
      Icons.add_circle_outline,
    ),
    IntroStep(
      'Your projects stay together',
      'Keep your pattern photo and reviewed instructions in one place. Reopen a project where you left off.',
      'Saved project + progress',
      Icons.bookmark_border,
    ),
    IntroStep(
      'Choose your first pattern',
      'Use a clear pattern page, stitch chart or close-up knitted swatch. Include printed counts if you want them copied into the guide.',
      'Photograph a knitting pattern',
      Icons.camera_alt_outlined,
    ),
  ],
  'drawing' => const [
    IntroStep(
      'Your doodle is the hero',
      'Turn your own drawing into a short illustrated comic. The character comes from your photo, not our mascot.',
      'Doodle → comic',
      Icons.draw_outlined,
    ),
    IntroStep(
      'Show your drawing clearly',
      'Photograph one original doodle on paper, straight on. Fill the frame with the drawing and avoid shadows.',
      'Your drawing on paper',
      Icons.crop_free,
    ),
    IntroStep(
      'Meet your character',
      'AI reads the visible shapes and colors of your drawing. It uses your artwork as the reference for the comic.',
      'Same character, new adventure',
      Icons.face_outlined,
    ),
    IntroStep(
      'See new scenes',
      'Your character appears in different illustrated settings and actions. Generated artwork may vary from the original lines.',
      'Explore · discover · return',
      Icons.auto_awesome_outlined,
    ),
    IntroStep(
      'Make the story yours',
      'Review short captions and edit the words. Keep the comic gentle, playful and personal.',
      'Edit a caption',
      Icons.edit_outlined,
    ),
    IntroStep(
      'Keep or share the comic',
      'Save your comic and reopen it from your bookshelf. Share an illustrated page when you are happy with it.',
      'Your illustrated bookshelf',
      Icons.menu_book_outlined,
    ),
    IntroStep(
      'Start with your own doodle',
      'Take a clear photo of a character you drew or choose one from your library. Photos without a drawing are rejected.',
      'Photograph your doodle',
      Icons.camera_alt_outlined,
    ),
  ],
  'fridge' => const [
    IntroStep(
      'See what needs using',
      'Keep track of food in your fridge, freezer and pantry. EatSoon puts upcoming check dates first.',
      'Food → check dates',
      Icons.kitchen,
    ),
    IntroStep(
      'Photograph visible food',
      'Show the inside of your fridge or a few food packages. Face labels toward the camera and avoid hiding items.',
      'Visible items, readable labels',
      Icons.photo_camera,
    ),
    IntroStep(
      'Review the food list',
      'Check each detected item before adding it. Remove mistakes or edit the name and storage location.',
      'Select the items to keep',
      Icons.checklist,
    ),
    IntroStep(
      'Dates need your judgment',
      'Printed dates are copied when readable; other dates are approximate reminders. A photo cannot tell whether food is safe to eat.',
      'Label date or check estimate',
      Icons.event_outlined,
    ),
    IntroStep(
      'Mark food as used',
      'Tap Used when an item is gone. Undo restores an item if you tapped by mistake.',
      'Use → history → undo',
      Icons.check_circle_outline,
    ),
    IntroStep(
      'Get optional reminders',
      'Enable date reminders from settings when you want them. Always follow labels and normal food handling guidance.',
      'Check the label',
      Icons.notifications_none,
    ),
    IntroStep(
      'Show your fridge or packages',
      'Take a clear photo with food visible and labels facing you. You will review the detected list before it reaches your dashboard.',
      'Photograph your food',
      Icons.camera_alt_outlined,
    ),
  ],
  'plant' => const [
    IntroStep(
      'Care for your own plants',
      'Save each houseplant with a photo and care notes. Tendly helps you remember when to check its soil.',
      'Plant → care rhythm',
      Icons.local_florist_outlined,
    ),
    IntroStep(
      'Show leaves and the pot',
      'Photograph one plant in daylight. Keep its leaves clear and include the pot when possible.',
      'One houseplant in focus',
      Icons.photo_camera,
    ),
    IntroStep(
      'Review the identification',
      'AI suggests a likely species and light preference. Check the result because similar plants can be confused.',
      'Likely species + light',
      Icons.edit_outlined,
    ),
    IntroStep(
      'Check before watering',
      'Choose a soil-check interval that suits your plant and room. A reminder is a prompt to check, not an automatic watering order.',
      'Check soil → decide',
      Icons.water_drop_outlined,
    ),
    IntroStep(
      'Record what you did',
      'Mark Watered after watering, or Damp if the soil still feels wet. Your care history keeps those observations.',
      'Watered · damp',
      Icons.history,
    ),
    IntroStep(
      'Care without guesswork',
      'Adjust the schedule as you learn your plant. Enable reminders in settings if you want a nudge.',
      'Your plant, your rhythm',
      Icons.notifications_none,
    ),
    IntroStep(
      'Add your first houseplant',
      'Take a bright photo of the whole plant with clear leaves. Review its suggested care details before saving.',
      'Photograph one houseplant',
      Icons.camera_alt_outlined,
    ),
  ],
  'maintenance' => const [
    IntroStep(
      'A log for your vehicle',
      'Keep actual service work and mileage in one place. Odoly builds a history from records you review.',
      'Vehicle → service history',
      Icons.directions_car_outlined,
    ),
    IntroStep(
      'Start with a record',
      'Photograph a service receipt, maintenance note or odometer. Keep printed dates, tasks and mileage readable.',
      'Receipt or odometer',
      Icons.receipt_long_outlined,
    ),
    IntroStep(
      'Review what was read',
      'Check the vehicle, mileage, units and service date. Missing information stays blank until you add it.',
      'Observed details only',
      Icons.edit_outlined,
    ),
    IntroStep(
      'Keep units clear',
      'Choose kilometers or miles from your record. Odoly does not guess units when none are printed.',
      'km · miles · unknown',
      Icons.speed_outlined,
    ),
    IntroStep(
      'Plan the next service',
      'Add a next service date based on your vehicle guidance. Receipt scanning does not diagnose repairs or invent intervals.',
      'Your next service date',
      Icons.calendar_month,
    ),
    IntroStep(
      'Revisit your history',
      'Open earlier services to see what was done. Optional reminders help you check a date you set.',
      'Service log + reminders',
      Icons.history,
    ),
    IntroStep(
      'Photograph a receipt or display',
      'Use a clear vehicle service receipt, maintenance note or odometer photo. You can record the details manually instead.',
      'Readable vehicle record',
      Icons.camera_alt_outlined,
    ),
  ],
  'ticket' => const [
    IntroStep(
      'Keep the nights you remember',
      'Save event tickets and the memories behind them. Stubloom makes a personal archive of your experiences.',
      'Ticket → memory',
      Icons.confirmation_number_outlined,
    ),
    IntroStep(
      'Show the event details',
      'Photograph a ticket or upload an event booking screenshot. Keep the event name, venue and date readable.',
      'Event name + date',
      Icons.photo_camera,
    ),
    IntroStep(
      'Cover the barcode',
      'Visible barcodes are covered locally before analysis. Check your photo and avoid adding payment details.',
      'Private code, visible event',
      Icons.qr_code,
    ),
    IntroStep(
      'Review your ticket',
      'Check the extracted name, venue and date. Blank details need your input; a ticket alone does not prove attendance.',
      'Review before saving',
      Icons.edit_outlined,
    ),
    IntroStep(
      'Add the memory',
      'Mark an event as attended when you were there. Add the moment you want to remember in your own words.',
      'Your memory, your words',
      Icons.favorite_border,
    ),
    IntroStep(
      'Make a year poster',
      'Your confirmed, dated events can become a poster. Browse the collection by event type or year.',
      'A year of experiences',
      Icons.collections_outlined,
    ),
    IntroStep(
      'Choose an event ticket',
      'Take a readable ticket photo or use a booking screenshot. You will review the event details before saving.',
      'Photograph an event ticket',
      Icons.camera_alt_outlined,
    ),
  ],
  _ => const [],
};

class FeatureOnboarding extends StatefulWidget {
  final VoidCallback onDone;
  final VoidCallback? onManual;
  const FeatureOnboarding({super.key, required this.onDone, this.onManual});
  @override
  State<FeatureOnboarding> createState() => _FeatureOnboardingState();
}

class _FeatureOnboardingState extends State<FeatureOnboarding> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final steps = introSteps, step = steps[index];
    return Column(
      children: [
        const MainTitle(appName),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Text(
                  '${index + 1} of ${steps.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 20),
                FeatureDemo(kind: appKind, index: index, step: step),
                const SizedBox(height: 28),
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(step.body, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: MainAction(
            index == 0
                ? 'Get started'
                : index == steps.length - 1
                ? 'Try it now'
                : 'Next',
            () => index == steps.length - 1
                ? widget.onDone()
                : setState(() => index++),
            icon: Icons.arrow_forward,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            if (index > 0)
              TextButton(
                onPressed: () => setState(() => index--),
                child: const Text('Back'),
              ),
            TextButton(
              onPressed: widget.onManual,
              child: const Text('Enter manually'),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class FeatureDemo extends StatelessWidget {
  final String kind;
  final int index;
  final IntroStep step;
  const FeatureDemo({
    super.key,
    required this.kind,
    required this.index,
    required this.step,
  });
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 300,
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 450),
        child: kind == 'clothing'
            ? _ClothingDemo(index: index)
            : kind == 'drawing'
            ? _DoodleDemo(index: index)
            : Column(
                key: ValueKey('$kind.$index'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Example'), const SizedBox(height: 6),
                  SamplePreview(kind: kind, index: index),
                  const SizedBox(height: 12),
                  // Concrete sample output, rather than another paragraph of marketing copy.

                  Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      const Icon(Icons.photo_outlined, color: ink),
                      const Icon(Icons.arrow_forward, size: 20),
                      Icon(
                        index >= 3 ? step.icon : Icons.edit_outlined,
                        color: accent,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _ClothingDemo extends StatelessWidget {
  final int index;
  const _ClothingDemo({required this.index});
  @override
  Widget build(BuildContext context) => index == 3
      ? Column(
          children: [
            Expanded(
              child: Image.asset(
                'assets/v3/demos/boots-guide.png',
                fit: BoxFit.contain,
              ),
            ),
            const Text('Upright · side by side · facing you'),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(
                'assets/v3/demos/sweater.png',
                fit: BoxFit.contain,
              ),
            ),
            if (index != 1)
              Expanded(
                child: Image.asset(
                  'assets/v3/demos/jeans.png',
                  fit: BoxFit.contain,
                ),
              ),
          ],
        );
}

class _DoodleDemo extends StatelessWidget {
  final int index;
  const _DoodleDemo({required this.index});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: ink, width: 1.3)),
          child: const CustomPaint(
            size: Size(82, 100),
            painter: _SketchPainter(scene: 0),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.arrow_forward),
      ),
      Flexible(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(index),
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 700),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.rotate(angle: (1 - value) * .1, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in [1, 2])
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: ink)),
                    child: CustomPaint(
                      size: const Size(94, 80),
                      painter: _SketchPainter(scene: n),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SketchPainter extends CustomPainter {
  final int scene;
  const _SketchPainter({required this.scene});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ink
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final cx = size.width * .5, cy = size.height * .52;
    if (scene > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(0, size.height * .8)
          ..quadraticBezierTo(
            size.width * .3,
            size.height * .55,
            size.width,
            size.height * .87,
          ),
        p,
      );
      canvas.drawCircle(Offset(size.width * .8, size.height * .18), 8, p);
    }
    canvas.drawPath(
      Path()
        ..moveTo(cx - 20, cy - 18)
        ..lineTo(cx - 24, cy - 35)
        ..lineTo(cx - 8, cy - 26)
        ..quadraticBezierTo(cx, cy - 31, cx + 9, cy - 26)
        ..lineTo(cx + 23, cy - 34)
        ..lineTo(cx + 21, cy - 15)
        ..quadraticBezierTo(cx + 23, cy + 20, cx, cy + 22)
        ..quadraticBezierTo(cx - 24, cy + 17, cx - 20, cy - 18),
      p,
    );
    canvas.drawCircle(Offset(cx - 7, cy - 6), 1.8, p);
    canvas.drawCircle(Offset(cx + 7, cy - 6), 1.8, p);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 6, cy + 5)
        ..quadraticBezierTo(cx, cy + 12, cx + 7, cy + 4),
      p,
    );
    if (scene == 2) {
      canvas.drawPath(
        Path()
          ..moveTo(cx + 16, cy + 10)
          ..quadraticBezierTo(cx + 36, cy - 12, cx + 40, cy + 4),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_SketchPainter old) => old.scene != scene;
}

class SamplePreview extends StatelessWidget {
  final String kind;
  final int index;
  const SamplePreview({super.key, required this.kind, required this.index});
  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.titleLarge;
    if (kind == 'furniture') {
      return SizedBox(
        width: 200,
        height: 140,
        child: CustomPaint(painter: _FitDemoPainter(index >= 4)),
      );
    }
    if (kind == 'goal') {
      return SizedBox(
        width: 180,
        height: 140,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(index),
          tween: Tween(begin: .1, end: index >= 3 ? .5 : .1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 800),
          builder: (c, v, _) => CustomPaint(painter: _JarDemoPainter(v)),
        ),
      );
    }
    final rows = switch (kind) {
      'meal' =>
        index == 3
            ? ['2 servings → 4 servings', 'Pasta 200 g → 400 g']
            : index == 4
            ? ['1. Cook the pasta', '2. Stir in the sauce']
            : ['Tomato pasta', 'Pasta 200 g · tomatoes 150 g'],
      'fridge' =>
        index == 4
            ? ['Yogurt ✓ used', 'Undo returns it to the fridge']
            : ['Yogurt · check tomorrow', 'Carrots · check in 3 days'],
      'plant' =>
        index == 4
            ? ['Mon · soil damp', 'Thu · watered']
            : ['Pothos · bright indirect light', 'Check soil in 7 days'],
      'knitting' =>
        index >= 3
            ? ['K   P   K   P', 'Row 2 of your pattern']
            : ['Scarf pattern', 'Row 1: knit 12 stitches'],
      'maintenance' =>
        index == 3
            ? ['52,000 km', 'Units copied from the display']
            : ['Oil service · Oct 13', 'Oil and filter changed'],
      'ticket' =>
        index == 4
            ? ['Live at the park', 'Attended ✓ · your memory']
            : ['Live at the park', 'Jun 18 · Riverside stage'],
      _ => ['Your photo', 'Your reviewed draft'],
    };
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                row,
                style: row == rows.first ? title : null,
                textAlign: TextAlign.center,
              ),
            ),
          if (kind == 'knitting')
            const Icon(Icons.gesture, size: 36, color: accent),
        ],
      ),
    );
  }
}

class _FitDemoPainter extends CustomPainter {
  final bool rotate;
  const _FitDemoPainter(this.rotate);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    c.drawRect(const Rect.fromLTWH(25, 4, 120, 130), p);
    c.save();
    c.translate(85, 75);
    c.rotate(rotate ? .4 : 0);
    p.color = accent;
    c.drawRect(const Rect.fromLTWH(-65, -30, 130, 60), p);
    c.restore();
  }

  @override
  bool shouldRepaint(_FitDemoPainter old) => rotate != old.rotate;
}

class _JarDemoPainter extends CustomPainter {
  final double value;
  const _JarDemoPainter(this.value);
  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(
      const Rect.fromLTWH(35, 10, 110, 120),
      const Radius.circular(16),
    );
    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    c.drawRRect(r, p);
    c.save();
    c.clipRRect(r);
    p
      ..color = accent.withValues(alpha: .5)
      ..style = PaintingStyle.fill;
    c.drawRect(Rect.fromLTWH(35, 130 - 120 * value, 110, 120 * value), p);
    c.restore();
  }

  @override
  bool shouldRepaint(_JarDemoPainter old) => old.value != value;
}
