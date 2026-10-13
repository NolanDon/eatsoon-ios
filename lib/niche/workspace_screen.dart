import 'package:flutter/material.dart';

import '../screens/home_screen.dart' as legacy;
import 'journal.dart';
import 'draft.dart';
import 'workbench.dart';
import 'portion_ledger.dart';

class NicheScreen extends StatefulWidget {
  const NicheScreen({super.key});
  @override
  State<NicheScreen> createState() => _PackState();
}

class _PackState extends WorkbenchState<NicheScreen> {
  @override
  String get app => 'eatsoon';
  @override
  void validate(Record r) => validatePack(r);
  Future<void> add() async {
    final v = await editEntry(context, 'Open a portion ledger', [
      const EntryField('name', 'Opened food / pack name'),
      const EntryField(
        'portions',
        'Portions in this pack',
        initial: '4',
        min: 1,
        max: 10000,
        whole: true,
      ),
      EntryField(
        'opened',
        'Opened on',
        date: true,
        initial: dayText(DateTime.now()),
      ),
      EntryField(
        'labelDate',
        'Printed label date',
        date: true,
        initial: dayText(DateTime.now()),
      ),
      const EntryField(
        'location',
        'Storage location',
        options: ['Fridge', 'Freezer', 'Pantry'],
      ),
      const EntryField(
        'instructions',
        'Label type and after-opening instructions',
        multiline: true,
      ),
    ], draft: const DraftContext('eatsoon', 'opened-pack'));
    if (v != null) {
      await update(
        newRecord(v['name'] as String, {
          ...v,
          'events': <Record>[],
          'replace': false,
        }),
      );
    }
  }

  Future<void> use(Record r, String actionName) async {
    if (portionsLeft(r) == 0) return;
    final v = await editEntry(
      context,
      'Record ${actionName.toLowerCase()} portions',
      [
        EntryField(
          'count',
          'Portions',
          initial: '1',
          min: 1,
          max: portionsLeft(r).toDouble(),
          whole: true,
        ),
        const EntryField(
          'note',
          'Meal / reason',
          multiline: true,
          optional: true,
        ),
      ],
    );
    if (v != null) {
      await update({
        ...r,
        'events': [
          ...entries(r, 'events'),
          {
            ...v,
            'action': actionName,
            'date': DateTime.now().toIso8601String(),
          },
        ],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...records]
      ..sort(
        (a, b) =>
            dateValue(a, 'labelDate').compareTo(dateValue(b, 'labelDate')),
      );
    final replacement = records.where((e) => e['replace'] == true).toList();
    return page(
      title: 'EatSoon · Packs',
      subtitle: 'Know what remains after opening a pack. Record actual portions used or wasted and decide what belongs on your replacement list.',
      action: 'Open a portion ledger',
      onAdd: add,
      tools: const legacy.HomeScreen(),
      toolsLabel: 'Pantry expiry list & reminders',
      summary: replacement.isEmpty
          ? null
          : card('Replacement list', [
              Text(replacement.map((e) => e['name']).join(' · ')),
              action(
                'Copy replacement list',
                () => copyText(
                  replacement.map((e) => '- ${e['name']}').join('\n'),
                ),
                icon: Icons.copy,
              ),
            ]),
      children: [
        if (records.isEmpty)
          card('Track the opened pack, not just a date', [
            const Text(
              'Copy the printed label and after-opening instructions. A portion is a unit you choose. The ledger does not infer whether food is safe to eat.',
            ),
          ]),
        ...sorted.map(
          (r) => card(r['name'] as String, [
            Text(
              '${portionsLeft(r)} / ${r['portions']} portions remain',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            LinearProgressIndicator(
              value: portionsLeft(r) / (r['portions'] as int),
            ),
            const SizedBox(height: 8),
            Text(
              '${r['location']} · opened ${r['opened']}\nLabel date ${r['labelDate']}\n${r['instructions']}',
            ),
            Text(
              'Used ${portionTotal(r, 'Used')} · wasted ${portionTotal(r, 'Wasted')}',
            ),
            if (portionsLeft(r) > 0) ...[
              action(
                'Use portions',
                () => use(r, 'Used'),
                icon: Icons.restaurant,
              ),
              action(
                'Record wasted portions',
                () => use(r, 'Wasted'),
                icon: Icons.remove_circle_outline,
              ),
            ],
            action('Undo last portion entry', () {
              final events = entries(r, 'events');
              if (events.isNotEmpty) {
                update({...r, 'events': events..removeLast()});
              }
            }, icon: Icons.undo),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add to replacement list'),
              value: r['replace'] as bool,
              onChanged: busy ? null : (v) => update({...r, 'replace': v!}),
            ),
            action(
              'Copy pack ledger',
              () => copyText(packReport(r)),
              icon: Icons.copy,
            ),
            action('Delete pack', () => remove(r), icon: Icons.delete_outline),
          ]),
        ),
      ],
    );
  }
}
