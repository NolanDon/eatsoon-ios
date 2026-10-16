import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsoon/v3/brand.dart';
import 'package:eatsoon/v3/onboarding.dart';
import 'package:eatsoon/v3/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async { await (FontLoader(brandFont)..addFont(rootBundle.load('assets/v3/fonts/bricolage.ttf'))..addFont(rootBundle.load('assets/v3/fonts/bricolage.ttf'))).load(); });
  testWidgets('forward arrow follows a large primary CTA label', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: v3Theme(), home: Scaffold(body: MainAction('Open my kitchen', () {}, icon: Icons.arrow_forward))));
    final label = find.text('Open my kitchen'), arrow = find.byIcon(Icons.arrow_forward);
    expect(tester.getCenter(arrow).dx, greaterThan(tester.getCenter(label).dx));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style?.textStyle?.resolve({})?.fontSize ?? v3Theme().filledButtonTheme.style!.textStyle!.resolve({})!.fontSize, greaterThanOrEqualTo(22));
  });
  testWidgets('first onboarding explanation fits without scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: v3Theme(), home: Scaffold(body: SafeArea(child: FeatureOnboarding(onDone: () {})))));
    await tester.pumpAndSettle();
    final title = find.text(introSteps.first.title);
    expect(tester.getRect(title).bottom, lessThan(tester.getRect(find.text('Open my kitchen')).top));
    expect(find.text('Type food details'), findsNothing);
    if (appKind == 'drawing') {
      expect(find.text(introSteps.first.body), findsNothing);
      expect(find.text('Type food details'), findsNothing);
    } else {
      final body = find.text(introSteps.first.body);
      expect(tester.getRect(body).bottom, lessThan(tester.getRect(find.text('Open my kitchen')).top));
      expect(tester.getRect(body).top, greaterThan(tester.getRect(title).bottom));
    }
    expect(tester.takeException(), isNull);
  });
  test('secondary controls use a small brand font on either platform', () {
    final style = v3Theme().textButtonTheme.style!.textStyle!.resolve({})!;
    expect(style.fontSize, 16); expect(style.fontFamily, brandFont);
  });
  testWidgets('larger demos leave explanation visible and Back is at top left', (tester) async {
    tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:v3Theme(),home:Scaffold(body:SafeArea(child:FeatureOnboarding(onDone:() {})))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FeatureDemo)).height, greaterThan(250));
    expect(tester.getRect(find.text(introSteps.first.title)).top - tester.getRect(find.byType(FeatureDemo)).bottom, greaterThanOrEqualTo(23));
    final logo = find.byWidgetPredicate((w)=>w is Image && w.image is AssetImage && (w.image as AssetImage).assetName=='assets/v3/brand/mark.png');
    expect(logo,findsOneWidget); expect(tester.getCenter(logo).dx,lessThan(tester.getRect(find.text(appName)).left));
    await tester.tap(find.text('Open my kitchen')); await tester.pumpAndSettle();
    final back = find.byTooltip('Back');expect(back,findsOneWidget);
    expect(tester.getCenter(back).dx,lessThan(tester.getRect(logo).left));
    expect(tester.getCenter(back).dy,lessThan(100));
    expect(find.text('Type food details'),findsNothing);
    await tester.tap(back);await tester.pumpAndSettle();expect(find.text(introSteps.first.title),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

}
