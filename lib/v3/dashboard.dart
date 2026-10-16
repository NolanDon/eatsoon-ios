import 'package:flutter/material.dart';

import 'actions.dart';
import '../experience/experience_preferences.dart';
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
    if (!await confirm(
      context,
      'Mark ${item['name']} as gone?',
      'This moves it out of your current food list. You can undo this afterward.',
      action: 'Mark gone',
    ))
      return;
    await a.update({...item, 'used': true, 'usedDate': day(DateTime.now())});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['name']} marked gone'),
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
            .where(
              (v) =>
                  location == 'used' ||
                  ExperiencePreferences.instance.integer('pantryView', 0) !=
                      1 ||
                  (dateOrNull(v['nextDate'])?.isBefore(
                        DateTime.now().add(const Duration(days: 3)),
                      ) ??
                      false),
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
                    final when =
                        dateOrNull(item['labelDate']) ??
                        dateOrNull(item['nextDate']);
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
                          width: 38,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(foodIcon(item), size: 23, color: ink),
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
                                  style: TextStyle(
                                    color: expiryColor(days),
                                    fontWeight: FontWeight.w700,
                                  ),
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
                          tooltip: 'Mark food as gone',
                          onPressed: () => used(item),
                          icon: const Icon(Icons.remove_circle_outline),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Item options',
                          icon: const Icon(Icons.more_horiz),
                          onSelected: (v) =>
                              v == 'edit' ? a.edit(item) : a.remove(item),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20),
                                  SizedBox(width: 12),
                                  Text('Edit item'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 20),
                                  SizedBox(width: 12),
                                  Text('Delete'),
                                ],
                              ),
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
            all.isEmpty ? 'Scan the fridge' : 'Add more items',
            () async {
              if (all.isNotEmpty &&
                  !await confirm(
                    context,
                    'Add to your kitchen',
                    'Your current food stays. Repeated items are skipped; new purchases with a different label date are kept separately.',
                    action: 'Add more',
                  ))
                return;
              a.add();
            },
            icon: Icons.camera_alt_outlined,
          ),
        ),
      ],
    );
  }
}

IconData foodIcon(Item item) {
  final value = '${item['category'] ?? ''} ${item['name'] ?? ''}'.toLowerCase();
  bool matches(String pattern) => RegExp(pattern).hasMatch(value);
  if (matches(r'egg')) return Icons.egg_outlined;
  if (matches(r'milk|yogurt|cheese|cream|butter|dairy'))
    return Icons.local_drink_outlined;
  if (matches(r'apple|banana|berry|berries|fruit|orange|grape|lemon'))
    return Icons.apple_outlined;
  if (matches(
    r'carrot|broccoli|lettuce|spinach|vegetable|tomato|pepper|onion|salad',
  ))
    return Icons.eco_outlined;
  if (matches(r'meat|chicken|beef|pork|fish|salmon|tofu|protein'))
    return Icons.set_meal_outlined;
  if (matches(r'bread|rice|pasta|grain|cereal|oat|flour'))
    return Icons.bakery_dining_outlined;
  if (matches(r'juice|water|drink|soda|coffee|tea'))
    return Icons.local_cafe_outlined;
  if (item['location'] == 'freezer') return Icons.ac_unit;
  return Icons.shopping_basket_outlined;
}

Color expiryColor(int? days) {
  if (days == null) return ink;
  if (days <= 1) return const Color(0xFFB42318);
  if (days <= 3) return const Color(0xFFAD4700);
  if (days <= 6) return const Color(0xFF816000);
  return const Color(0xFF277044);
}
