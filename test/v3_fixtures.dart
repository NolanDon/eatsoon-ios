import 'package:eatsoon/v3/model.dart';

Item fixture(String kind, {String id = 'fixture'}) => {
  'id': id,
  'name': switch (kind) {
    'clothing' => 'Cream shirt',
    'fridge' => 'Yogurt',
    'plant' => 'Pothos',
    'meal' => 'Pasta bowl',
    'knitting' => 'Rib scarf',
    'furniture' => 'Reading chair',
    'drawing' => 'Space fox',
    'ticket' => 'Friday concert',
    'maintenance' => 'Oil service',
    _ => 'Weekend trip',
  },
  ...switch (kind) {
    'clothing' => {'category': 'top', 'color': 'cream', 'style': 'casual'},
    'fridge' => {
      'location': 'fridge',
      'checkDays': 3,
      'labelDate': null,
      'nextDate': '2026-10-18',
      'estimated': true,
    },
    'plant' => {
      'species': 'Epipremnum aureum',
      'checkDays': 7,
      'light': 'bright indirect',
      'nextDate': '2026-10-20',
      'note': 'Check the soil.',
      'confidence': .85,
    },
    'meal' => {
      'servings': 2,
      'ingredients': [
        {'name': 'Pasta', 'amount': 200, 'unit': 'g'},
        {'name': 'Tomatoes', 'amount': 150, 'unit': 'g'},
      ],
      'steps': ['Cook the pasta.', 'Add the sauce and serve.'],
      'estimated': true,
    },
    'knitting' => {
      'stitch': 'rib',
      'castOn': 20,
      'rows': [
        {'instruction': 'Knit one stitch.', 'symbol': 'K', 'count': 1},
        {'instruction': 'Purl one stitch.', 'symbol': 'P', 'count': 1},
      ],
      'row': 0,
      'estimated': true,
    },
    'furniture' => {
      'width': 70,
      'depth': 60,
      'height': 90,
      'doorWidth': 82,
      'doorHeight': 200,
      'unit': 'cm',
    },
    'drawing' => {
      'panels': [
        {
          'caption': 'A fox discovers a star.',
          'scene': 'space',
          'position': 'left',
        },
        {
          'caption': 'The star begins to glow.',
          'scene': 'sky',
          'position': 'center',
        },
        {
          'caption': 'A new adventure awaits.',
          'scene': 'forest',
          'position': 'right',
        },
      ],
    },
    'ticket' => {
      'artist': 'Local band',
      'venue': 'The hall',
      'date': '2026-10-10',
      'category': 'concert',
      'memory': 'The encore was great.',
      'attended': true,
    },
    'maintenance' => {
      'vehicle': 'My hatchback',
      'date': '2026-10-10',
      'mileage': 52000,
      'mileageUnit': 'km',
      'nextServiceDate': '2027-04-10',
      'tasks': ['Oil and filter changed'],
    },
    _ => {
      'target': 500,
      'saved': 50,
      'currency': 'CAD',
      'deadline': '2026-12-01',
    },
  },
};
