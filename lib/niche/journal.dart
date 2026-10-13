import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

typedef Record = Map<String, dynamic>;
typedef RecordValidator = void Function(Record);

int _sequence = 0;
Record newRecord(String name, Record values) => {
  'id': '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
  'name': name.trim(),
  'created': DateTime.now().toIso8601String(),
  ...values,
};

void check(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

String textValue(
  Record r,
  String key, {
  int max = 4000,
  bool optional = false,
}) {
  final v = r[key];
  check(v is String, 'Missing $key.');
  final s = v as String;
  check(s.length <= max && (optional || s.trim().isNotEmpty), 'Check $key.');
  return s;
}

double number(Record r, String key, {double min = 0, double max = 1000000}) {
  final v = r[key];
  check(v is num, 'Missing $key.');
  final n = (v as num).toDouble();
  check(n.isFinite && n >= min && n <= max, 'Check $key ($min–$max).');
  return n;
}

int integer(Record r, String key, {int min = 0, int max = 1000000}) {
  final v = number(r, key, min: min.toDouble(), max: max.toDouble());
  check(v == v.roundToDouble(), '$key must be a whole number.');
  return v.toInt();
}

List<Record> entries(Record r, String key) {
  final value = r[key];
  check(value is List && value.length <= 2000, 'Check $key.');
  return (value as List).map((e) {
    check(e is Map, 'Invalid $key entry.');
    return Map<String, dynamic>.from(e as Map);
  }).toList();
}

DateTime dateValue(Record r, String key) {
  final value = textValue(r, key, max: 40);
  final prefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T|$)').firstMatch(value);
  check(prefix != null, 'Check $key date.');
  final year = int.parse(prefix!.group(1)!);
  final month = int.parse(prefix.group(2)!);
  final day = int.parse(prefix.group(3)!);
  final calendar = DateTime(year, month, day);
  check(
    calendar.year == year && calendar.month == month && calendar.day == day,
    'Check $key date.',
  );
  final parsed = DateTime.tryParse(value);
  check(parsed != null, 'Check $key date.');
  return parsed!;
}

String dayText(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String decimal(num n) =>
    n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
String csvCell(Object? value) =>
    '"${(value ?? '').toString().replaceAll('"', '""')}"';

/// Each application owns its validation, calculations and record schema.
/// This shared storage infrastructure writes a distinct versioned key, leaving
/// existing subscriber records untouched. Failed reads never silently reset data.
class JournalStore {
  final String app;
  final RecordValidator validate;
  final SharedPreferences prefs;
  Future<void> _tail = Future.value();
  JournalStore(this.app, this.validate, this.prefs);
  String get key => 'niche.$app.v1';

  List<Record> decode(String raw) {
    check(raw.length <= 4000000, 'Backup is too large.');
    final data = jsonDecode(raw);
    check(
      data is Map &&
          data['schema'] == 1 &&
          data['app'] == app &&
          data['records'] is List,
      'This backup belongs to a different app or version.',
    );
    final records = entries(Map<String, dynamic>.from(data as Map), 'records');
    final ids = <String>{};
    for (final r in records) {
      final id = textValue(r, 'id', max: 100);
      check(ids.add(id), 'Duplicate record identifier.');
      textValue(r, 'name', max: 120);
      dateValue(r, 'created');
      validate(r);
    }
    return records;
  }

  List<Record> read() {
    final raw = prefs.getString(key);
    return raw == null ? [] : decode(raw);
  }

  String encode(List<Record> records) =>
      jsonEncode({'schema': 1, 'app': app, 'records': records});
  Future<List<Record>> change(void Function(List<Record>) mutation) {
    final result = _tail.then((_) async {
      final records = read();
      mutation(records);
      final raw = encode(records);
      final checked = decode(raw);
      if (!await prefs.setString(key, raw)) {
        throw const FormatException(
          'Could not save. Your previous records are still available.',
        );
      }
      return checked;
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<List<Record>> restore(String raw) async {
    final incoming = decode(raw);
    return change((records) {
      final ids = records.map((e) => e['id']).toSet();
      for (final r in incoming) {
        check(
          !ids.contains(r['id']),
          'This backup overlaps existing records. No records were changed.',
        );
      }
      records.addAll(incoming);
    });
  }

  Future<List<Record>> replaceUnreadable(String raw) {
    final incoming = decode(raw);
    final result = _tail.then((_) async {
      if (!await prefs.setString(key, encode(incoming))) {
        throw const FormatException(
          'Could not restore. Original data is preserved.',
        );
      }
      return incoming;
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
