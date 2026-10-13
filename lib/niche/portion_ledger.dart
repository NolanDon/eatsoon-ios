import 'journal.dart';

void validatePack(Record r) {
  integer(r, 'portions', min: 1, max: 10000);
  dateValue(r, 'opened');
  dateValue(r, 'labelDate');
  textValue(r, 'instructions', max: 4000);
  textValue(r, 'location', max: 120);
  final events = entries(r, 'events');
  for (final e in events) {
    check(['Used', 'Wasted'].contains(e['action']), 'Choose used or wasted.');
    integer(e, 'count', min: 1, max: 10000);
    dateValue(e, 'date');
    textValue(e, 'note', optional: true);
  }
  check(portionsLeft(r) >= 0, 'This action exceeds the remaining portions.');
  check(r['replace'] is bool, 'Check replacement choice.');
}

int portionsLeft(Record r) =>
    (r['portions'] as int) -
    entries(r, 'events').fold<int>(0, (sum, e) => sum + (e['count'] as int));
int portionTotal(Record r, String action) => entries(r, 'events')
    .where((e) => e['action'] == action)
    .fold<int>(0, (sum, e) => sum + (e['count'] as int));
String packReport(Record r) =>
    'EatSoon · ${r['name']}\nOpened ${r['opened']} · label date ${r['labelDate']}\n${r['location']} · label instructions ${r['instructions']}\n${portionsLeft(r)} portions remain; used ${portionTotal(r, 'Used')}; wasted ${portionTotal(r, 'Wasted')}\n${entries(r, 'events').map((e) => '${e['date']}, ${e['action']}, ${e['count']} portions, ${e['note']}').join('\n')}\nDates are user-entered label records, not a food-safety determination.';
