import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/v3/model.dart';
import 'v3_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rescans preserve existing food, dates and notes; new batches append', () async {
    SharedPreferences.setMockInitialValues({});
    final store = V3Store('eatsoon', 'fridge', await SharedPreferences.getInstance());
    final original = {...fixture('fridge'), 'name': 'Yogurt', 'note': 'Keep for breakfast'};
    await store.addAll([original]);
    final id = store.items.single['id'];
    await store.addAll([{...original, 'name': '  yogurt  ', 'nextDate': '2026-10-30'}, {...original, 'name': '  yogurt  '}]);
    expect(store.items, hasLength(1));
    expect(store.items.single['id'], id);
    expect(store.items.single['nextDate'], original['nextDate']);
    expect(store.items.single['note'], 'Keep for breakfast');
    await store.addAll([{...original, 'labelDate': '2026-11-01'}]);
    expect(store.items, hasLength(2));
    await store.update({...store.items.first, 'used': true});
    await store.addAll([original]);
    expect(store.items, hasLength(3));
  });
}
