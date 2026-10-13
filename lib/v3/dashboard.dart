import 'package:flutter/material.dart';

import 'actions.dart';
import 'brand.dart';
import 'model.dart';
import 'widgets.dart';

class Dashboard extends StatefulWidget {
  final DashboardActions actions;
  const Dashboard({super.key, required this.actions});
  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard> {
  String location = 'all';
  DashboardActions get a => widget.actions;
  void startFirst() {
    if (a.store.items.isNotEmpty) a.edit(a.store.items.first);
  }

  Future<void> used(Item item) async {
    await a.update({...item, 'used': true, 'usedDate': day(DateTime.now())});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['name']} used'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                a.update({...item, 'used': false, 'usedDate': null}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = a.store.items.where((v) => v['used'] != true).toList();
    final items =
        (location == 'used'
                ? a.store.items.where((v) => v['used'] == true)
                : all)
            .where(
              (v) =>
                  location == 'all' ||
                  location == 'used' ||
                  v['location'] == location,
            )
            .toList()
          ..sort(
            (a, b) => (a['nextDate'] ?? '9999').toString().compareTo(
              (b['nextDate'] ?? '9999').toString(),
            ),
          );
    final due = all
        .where(
          (v) => dateOrNull(v['nextDate'])?.isBefore(DateTime.now()) == true,
        )
        .length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '${all.length} items',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('$due to check', style: const TextStyle(color: ink)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              for (final value in [
                'all',
                'fridge',
                'freezer',
                'pantry',
                'used',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(value == 'all' ? 'Use first' : value),
                    selected: location == value,
                    onSelected: (_) => setState(() => location = value),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyView(
                  'See what you have',
                  'Scan your fridge, then check the detected items.',
                  Icons.kitchen_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, i) => const Divider(height: 30),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final when = dateOrNull(item['nextDate']);
                    final days = when
                        ?.difference(
                          DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day,
                          ),
                        )
                        .inDays;
                    return Row(
                      children: [
                        Container(
                          width: 54,
                          height: 66,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item['location'] == 'freezer'
                                ? Icons.ac_unit
                                : Icons.egg_outlined,
                            size: 30,
                            color: ink,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => a.edit(item),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['labelDate'] != null
                                      ? '${item['dateSource'] == 'manual' ? 'Your date' : 'Label'} ${item['labelDate']}'
                                      : days == null
                                      ? 'Date to confirm'
                                      : days <= 0
                                      ? 'Check today'
                                      : 'Check in $days days',
                                ),
                                if (item['labelDate'] == null)
                                  const Text(
                                    'Estimate',
                                    style: TextStyle(fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mark used',
                          onPressed: () => used(item),
                          icon: const Icon(Icons.check_circle_outline),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            minimumSize: const Size(54, 54),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) =>
                              v == 'edit' ? a.edit(item) : a.remove(item),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit item'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: MainAction(
            'Scan the fridge',
            a.add,
            icon: Icons.camera_alt_outlined,
          ),
        ),
      ],
    );
  }
}
