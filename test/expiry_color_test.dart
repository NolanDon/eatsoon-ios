import 'package:flutter_test/flutter_test.dart';
import 'package:eatsoon/v3/dashboard.dart';
import 'package:eatsoon/v3/brand.dart';

void main() {
  test('date urgency includes overdue dates and clear threshold bands', () {
    expect(expiryColor(-4), expiryColor(1));
    expect(expiryColor(2), expiryColor(3));
    expect(expiryColor(4), expiryColor(6));
    expect(expiryColor(7), expiryColor(30));
    expect(
      {expiryColor(1), expiryColor(3), expiryColor(5), expiryColor(7)}.length,
      4,
    );
    expect(expiryColor(null), ink);
  });
}
