import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsoon/v3/brand.dart';
import 'package:eatsoon/v3/onboarding.dart';
import 'package:eatsoon/v3/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async { await (FontLoader(brandFont)..addFont(rootBundle.load('assets/v3/fonts/brand.ttf'))..addFont(rootBundle.load('assets/v3/fonts/bold.ttf'))).load(); });
  testWidgets('forward arrow follows a large primary CTA label', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: v3Theme(), home: Scaffold(body: MainAction('Get started', () {}, icon: Icons.arrow_forward))));
    final label = find.text('Get started'), arrow = find.byIcon(Icons.arrow_forward);
    expect(tester.getCenter(arrow).dx, greaterThan(tester.getCenter(label).dx));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style?.textStyle?.resolve({})?.fontSize ?? v3Theme().filledButtonTheme.style!.textStyle!.resolve({})!.fontSize, greaterThanOrEqualTo(22));
  });
  testWidgets('first onboarding explanation fits without scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: v3Theme(), home: Scaffold(body: SafeArea(child: FeatureOnboarding(onDone: () {}, onManual: () {})))));
    await tester.pumpAndSettle();
    final title = find.text(introSteps.first.title);
    expect(tester.getRect(title).bottom, lessThan(tester.getRect(find.text('Get started')).top));
    if (appKind == 'drawing') {
      expect(find.text(introSteps.first.body), findsNothing);
      expect(find.text('Enter manually'), findsNothing);
    } else {
      final body = find.text(introSteps.first.body);
      expect(tester.getRect(body).bottom, lessThan(tester.getRect(find.text('Get started')).top));
      expect(tester.getRect(body).top, greaterThan(tester.getRect(title).bottom));
    }
    expect(tester.takeException(), isNull);
  });
}
