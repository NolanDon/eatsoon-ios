import 'package:flutter/material.dart';

import 'brand.dart';
import 'model.dart';
import 'widgets.dart';

Future<Item?> editItem(
  BuildContext context, {
  Item? value,
  String directory = '',
}) => Navigator.push<Item>(
  context,
  MaterialPageRoute(
    builder: (_) => ItemEditor(value: value, directory: directory),
  ),
);

class ItemEditor extends StatefulWidget {
  final Item? value;
  final String directory;
  const ItemEditor({super.key, this.value, this.directory = ''});
  @override
  State<ItemEditor> createState() => _EditorState();
}

class _EditorState extends State<ItemEditor> {
  final form = GlobalKey<FormState>();
  late Item item = {...defaults(), ...?widget.value};
  final controllers = <String, TextEditingController>{};
  @override
  void initState() {
    super.initState();
    if (appKind == 'goal' &&
        (item['currency'] ?? '').toString().trim().isEmpty) {
      item['currency'] = 'CAD';
    }
  }

  TextEditingController controller(String key, [String initial = '']) =>
      controllers.putIfAbsent(
        key,
        () => TextEditingController(text: item[key]?.toString() ?? initial),
      );
  Item defaults() => switch (appKind) {
    'clothing' => {'category': 'top', 'color': 'cream', 'style': 'casual'},
    'fridge' => {
      'location': 'fridge',
      'checkDays': 3,
      'estimated': false,
      'nextDate': day(DateTime.now().add(const Duration(days: 3))),
    },
    'meal' => {
      'servings': 2,
      'ingredients': <Item>[],
      'steps': <String>[],
      'estimated': false,
    },
    'plant' => {
      'species': '',
      'checkDays': 7,
      'light': 'bright indirect',
      'confidence': 0,
      'note': 'Check soil before watering.',
      'nextDate': day(DateTime.now().add(const Duration(days: 7))),
    },
    'goal' => {'saved': 0, 'currency': 'CAD'},
    'knitting' => {
      'stitch': 'knit',
      'castOn': null,
      'rows': <Item>[
        {
          'instruction': 'Knit one stitch at a time.',
          'symbol': 'K',
          'count': null,
        },
      ],
      'estimated': false,
      'row': 0,
      'stitchesDone': 0,
    },
    'drawing' => {
      'panels': <Item>[
        {
          'caption': 'A small adventure begins.',
          'scene': 'sky',
          'position': 'left',
        },
        {
          'caption': 'A surprising new friend appears.',
          'scene': 'forest',
          'position': 'center',
        },
        {
          'caption': 'Together they find their way home.',
          'scene': 'plain',
          'position': 'right',
        },
      ],
    },
    'maintenance' => {
      'vehicle': '',
      'mileageUnit': 'unknown',
      'tasks': <String>['Record service'],
      'date': day(DateTime.now()),
    },
    'ticket' => {'artist': '', 'venue': '', 'category': 'concert'},
    _ => {'unit': 'cm'},
  };
  @override
  void dispose() {
    for (final value in controllers.values) {
      value.dispose();
    }
    super.dispose();
  }

  Widget field(
    String key,
    String label, {
    bool numeric = false,
    bool required = false,
    int lines = 1,
    String? initial,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller(key, initial ?? ''),
      decoration: InputDecoration(labelText: label),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      maxLines: lines,
      maxLength: key == 'memory'
          ? 160
          : lines > 1
          ? 2000
          : 120,
      validator: (text) {
        if (required && (text ?? '').trim().isEmpty) return 'Enter $label.';
        if (numeric && (text ?? '').isNotEmpty) {
          final n = double.tryParse(text!);
          if (n == null || !n.isFinite || n < 0 || n > 1000000) {
            return 'Check the amount.';
          }
        }
        return null;
      },
    ),
  );
  Widget choice(String key, String label, List<String> values) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: values.contains(item[key])
          ? item[key] as String
          : values.first,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) => setState(() => item[key] = v),
    ),
  );
  Widget date(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OutlinedButton.icon(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: dateOrNull(item[key]) ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (selected != null && mounted) {
          setState(() => item[key] = day(selected));
        }
      },
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(item[key]?.toString() ?? label),
    ),
  );
  void save() {
    if (!form.currentState!.validate()) return;
    try {
      final result = {...item};
      for (final entry in controllers.entries) {
        final raw = entry.value.text.trim();
        if ([
          'servings',
          'checkDays',
          'mileage',
          'width',
          'height',
          'depth',
          'doorWidth',
          'doorHeight',
          'target',
          'saved',
          'castOn',
        ].contains(entry.key)) {
          result[entry.key] = raw.isEmpty ? null : double.parse(raw);
        } else {
          result[entry.key] = raw;
        }
      }
      if (appKind == 'meal') {
        if (controllers.containsKey('ingredientsText')) {
          result['ingredients'] = parseIngredients(
            controllers['ingredientsText']!.text,
          );
        }
        if (controllers.containsKey('stepsText')) {
          result['steps'] = controllers['stepsText']!.text
              .split('\n')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList();
        }
      }
      if (appKind == 'maintenance' && controllers.containsKey('tasksText')) {
        result['tasks'] = controllers['tasksText']!.text
            .split('\n')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();
      }
      if (appKind == 'fridge' || appKind == 'plant') {
        final preserved = widget.value?['nextDate'];
        final sameRhythm = result['checkDays'] == item['checkDays'];
        final logs = children(item, 'log');
        final baseDate =
            dateOrNull(
              appKind == 'plant' && logs.isNotEmpty
                  ? logs.last['date']
                  : item['created'],
            ) ??
            DateTime.now();
        result['nextDate'] =
            result['labelDate'] ??
            (preserved != null && sameRhythm
                ? preserved
                : day(
                    baseDate.add(
                      Duration(days: (result['checkDays'] as num).toInt()),
                    ),
                  ));
      }
      if (appKind == 'knitting') {
        if (controllers.containsKey('patternText')) {
          final original = children(item, 'rows');
          final lines = controllers['patternText']!.text
              .split('\n')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList();
          result['rows'] = [
            for (final line in lines)
              if (original.any((row) => row['instruction'] == line))
                original.firstWhere((row) => row['instruction'] == line)
              else
                {
                  'instruction': line,
                  'symbol':
                      RegExp(
                        r'^(K2TOG|YO|K|P)(?:\s|\d|$)',
                        caseSensitive: false,
                      ).firstMatch(line)?.group(1)?.toUpperCase() ??
                      'unknown',
                  'count': null,
                },
          ];
        }
      }
      if (appKind == 'drawing') {
        for (var i = 0; i < children(result, 'panels').length; i++) {
          if (controllers.containsKey('panel$i')) {
            (result['panels'] as List)[i]['caption'] = controllers['panel$i']!
                .text
                .trim();
          }
        }
      }
      for (final key in [
        'ingredientsText',
        'stepsText',
        'tasksText',
        'patternText',
        ...List.generate(6, (i) => 'panel$i'),
      ]) {
        result.remove(key);
      }
      validateItem(appKind, {'id': 'draft', ...result});
      Navigator.pop(context, result);
    } catch (e) {
      notice(context, e is FormatException ? e.message : 'Check the fields.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Form(
        key: form,
        child: Column(
          children: [
            MainTitle(
              widget.value == null ? 'Make it yours' : 'Review draft',
              trailing: IconButton(
                tooltip: 'Cancel',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  if (widget.directory.isNotEmpty && item['photo'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Photo(
                        item['cutout'] as String? ?? item['photo'] as String?,
                        widget.directory,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    ),
                  field('name', 'Name', required: true),
                  ...switch (appKind) {
                    'clothing' => [
                      choice('category', 'Type', [
                        'top',
                        'bottom',
                        'shoes',
                        'outerwear',
                        'dress',
                        'hat',
                        'bag',
                        'gloves',
                        'accessory',
                      ]),
                      choice('color', 'Color', [
                        'black',
                        'white',
                        'gray',
                        'cream',
                        'brown',
                        'blue',
                        'green',
                        'red',
                        'pink',
                        'purple',
                        'yellow',
                        'orange',
                      ]),
                      choice('style', 'Style', [
                        'casual',
                        'formal',
                        'sport',
                        'any',
                      ]),
                    ],
                    'fridge' => [
                      choice('location', 'Stored in', [
                        'fridge',
                        'freezer',
                        'pantry',
                      ]),
                      field(
                        'checkDays',
                        'Check again in days',
                        numeric: true,
                        required: true,
                      ),
                      date('labelDate', 'Add printed expiry date'),
                      const Text(
                        'Photo reminders are estimates. Check the label.',
                      ),
                    ],
                    'plant' => [
                      field('species', 'Species'),
                      field(
                        'checkDays',
                        'Soil check every few days',
                        numeric: true,
                        required: true,
                      ),
                      choice('light', 'Light', [
                        'bright indirect',
                        'direct light',
                        'low light',
                        'unknown',
                      ]),
                      const Text('Check soil before deciding to water.'),
                    ],
                    'meal' => [
                      field(
                        'servings',
                        'Servings',
                        numeric: true,
                        required: true,
                      ),
                      field(
                        'ingredientsText',
                        'Ingredients',
                        lines: 5,
                        required: true,
                        initial: children(item, 'ingredients')
                            .map(
                              (v) => '${v['amount']} ${v['unit']} ${v['name']}',
                            )
                            .join('\n'),
                      ),
                      const Text('Example: 200 g pasta'),
                      const SizedBox(height: 12),
                      field(
                        'stepsText',
                        'Steps, one per line',
                        lines: 4,
                        required: true,
                        initial: (item['steps'] as List?)?.join('\n') ?? '',
                      ),
                      if (item['estimated'] == true)
                        const Text(
                          'Photo-inspired recipe. Review the ingredients.',
                        ),
                    ],
                    'furniture' => [
                      field('width', 'Item width in cm', numeric: true),
                      field('depth', 'Item depth in cm', numeric: true),
                      field('height', 'Item height in cm', numeric: true),
                      field(
                        'doorWidth',
                        'Clear opening width in cm',
                        numeric: true,
                      ),
                      field(
                        'doorHeight',
                        'Clear opening height in cm',
                        numeric: true,
                      ),
                      const Text(
                        'Use measured sizes, including handles and trim.',
                      ),
                    ],
                    'ticket' => [
                      field('artist', 'Artist or event'),
                      field('venue', 'Venue'),
                      field('memory', 'Your memory', lines: 2),
                      SwitchListTile(
                        title: const Text('I attended'),
                        value: item['attended'] == true,
                        onChanged: (v) => setState(() => item['attended'] = v),
                      ),
                      date('date', 'Choose event date'),
                      choice('category', 'Type', [
                        'concert',
                        'festival',
                        'theatre',
                        'sport',
                        'other',
                      ]),
                    ],
                    'goal' => [
                      field(
                        'target',
                        'Goal amount',
                        numeric: true,
                        required: true,
                      ),
                      field(
                        'saved',
                        'Already saved',
                        numeric: true,
                        required: true,
                      ),
                      field('currency', 'Currency'),
                      date('deadline', 'Choose deadline'),
                    ],
                    'knitting' => [
                      choice('stitch', 'Stitch', [
                        'knit',
                        'purl',
                        'rib',
                        'garter',
                        'stockinette',
                        'unknown',
                      ]),
                      field(
                        'castOn',
                        'Starting stitches, if known',
                        numeric: true,
                      ),
                      field(
                        'patternText',
                        'Rows, one per line',
                        lines: 5,
                        required: true,
                        initial: children(
                          item,
                          'rows',
                        ).map((v) => v['instruction']).join('\n'),
                      ),
                      if (item['estimated'] == true)
                        const Text(
                          'Check this photo interpretation against your pattern.',
                        ),
                    ],
                    'maintenance' => [
                      field('vehicle', 'Vehicle'),
                      field('mileage', 'Odometer reading', numeric: true),
                      choice('mileageUnit', 'Distance unit', [
                        'km',
                        'miles',
                        'unknown',
                      ]),
                      date('date', 'Service date'),
                      date('nextServiceDate', 'Choose next service'),
                      field(
                        'tasksText',
                        'Work recorded, one per line',
                        lines: 4,
                        required: true,
                        initial: (item['tasks'] as List?)?.join('\n') ?? '',
                      ),
                    ],
                    'drawing' => [
                      for (var i = 0; i < children(item, 'panels').length; i++)
                        field(
                          'panel$i',
                          'Panel ${i + 1}',
                          lines: 2,
                          required: true,
                          initial:
                              children(item, 'panels')[i]['caption'] as String,
                        ),
                    ],
                    _ => <Widget>[],
                  },
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: MainAction(
                'Stock my kitchen',
                save,
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

List<Item> parseIngredients(String raw) {
  final result = <Item>[];
  for (final line in raw.split('\n').where((v) => v.trim().isNotEmpty)) {
    final match = RegExp(
      r'^\s*(\d+(?:\.\d+)?)\s*(g|ml|tsp|tbsp|cup|piece)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    need(match != null, 'Use a line like: 200 g pasta');
    result.add({
      'amount': double.parse(match!.group(1)!),
      'unit': match.group(2)!.toLowerCase(),
      'name': match.group(3)!.trim(),
    });
  }
  need(result.isNotEmpty, 'Add an ingredient.');
  return result;
}
