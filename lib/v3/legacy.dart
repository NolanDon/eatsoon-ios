import 'model.dart';

/// Converts only explicit saved values. Originals remain untouched.
Item? legacyDraft(String kind, Item source) {
  final name = (source['name'] ?? source['nickname'] ?? '').toString();
  if (name.isEmpty && kind != 'maintenance') return null;
  switch (kind) {
    case 'fridge':
      if (source['expiryDate'] == null) return null;
      return {
        'name': name,
        'location': 'fridge',
        'checkDays': 3,
        'labelDate': day(DateTime.parse(source['expiryDate'] as String)),
        'dateSource': 'manual',
        'nextDate': day(DateTime.parse(source['expiryDate'] as String)),
        'estimated': false,
      };
    case 'plant':
      if (source['intervalDays'] == null) return null;
      final interval = whole(source['intervalDays'], min: 1, max: 365);
      return {
        'name': name,
        'species': '',
        'checkDays': interval,
        'light': 'unknown',
        'note': source['note'] ?? '',
        'nextDate': day(
          DateTime.parse(source['lastWatered'] as String)
              .add(Duration(days: interval)),
        ),
        'lastWatered': source['lastWatered'],
      };
    case 'meal':
      if (source['ingredients'] is! List) return null;
      return {
        'name': name,
        'servings': source['servings'],
        'ingredients': [
          for (final v in children(source, 'ingredients'))
            {
              'name': v['name'],
              'amount': v['quantity'] ?? v['amount'],
              'unit': v['unit'],
            },
        ],
        'steps': <String>[],
        'estimated': false,
      };
    case 'knitting':
      if (source['rowCount'] == null) return null;
      return {
        'name': name,
        'stitch': 'unknown',
        'row': source['rowCount'],
        'castOn': null,
        'rows': [
          {
            'instruction': 'Add your next pattern instruction.',
            'symbol': 'unknown',
            'count': null,
          },
        ],
        'estimated': false,
        'legacyNote': source['note'],
      };
    case 'maintenance':
      if (source['odometerMiles'] != null) {
        return {
          'name': name,
          'vehicle': name,
          'mileage': source['odometerMiles'],
          'mileageUnit': 'miles',
          'tasks': ['Odometer record'],
          'date': day(DateTime.parse(source['createdAt'] as String)),
        };
      }
      if (source['mileageAtService'] != null) {
        return {
          'name': (source['type'] ?? 'Previous service').toString(),
          'vehicle': '',
          'mileage': source['mileageAtService'],
          'mileageUnit': 'miles',
          'tasks': [
            (source['note'] ?? source['type'] ?? 'Previous service').toString(),
          ],
          'date': day(DateTime.parse(source['date'] as String)),
        };
      }
      return null;
    default:
      return null;
  }
}
