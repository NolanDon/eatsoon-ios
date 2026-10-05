import '../experience/review_service.dart';
import '../experience/experience_preferences.dart';

import 'package:eatsoon/models/food_item.dart';
import 'package:eatsoon/screens/add_item_sheet.dart';
import 'package:eatsoon/screens/paywall_screen.dart';
import 'package:eatsoon/screens/settings_screen.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:eatsoon/theme.dart';
import 'package:eatsoon/widgets/food_list_row.dart';
import 'package:eatsoon/widgets/hero_eat_first_card.dart';
import 'package:eatsoon/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home: "Eat first" hero card + urgency-sorted list.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final canAdd = ref.read(canAddMoreProvider);
    if (!canAdd) {
      _openPaywall(context, ref);
      return;
    }
    final result = await showModalBottomSheet<AddItemResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EatSoonColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddItemSheet(),
    );
    if (result == AddItemResult.limitReached && context.mounted) {
      _openPaywall(context, ref);
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    FoodItem item,
  ) async {
    final result = await showModalBottomSheet<AddItemResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EatSoonColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddItemSheet(item: item),
    );
    if (result == AddItemResult.usedUp && context.mounted) {
      _showUndoSnack(context, ref, 'Marked as used up');
                    await ReviewService.recordMeaningfulAction();
    }
  }

  void _openPaywall(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PaywallScreen(onDone: (_) => Navigator.of(context).pop()),
      ),
    );
  }

  void _showUndoSnack(BuildContext context, WidgetRef ref, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () => ref.read(itemsProvider.notifier).undoRemove(),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(experienceChangesProvider);
    final itemsAsync = ref.watch(itemsProvider);
    final canAddMore = ref.watch(canAddMoreProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EatSoon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (allItems) {
          final filter = ExperiencePreferences.instance.integer(
            'pantryView',
            0,
          );
          final cutoff = DateTime.now().add(const Duration(days: 3));
          final items = filter == 1
              ? allItems
                    .where((item) => !item.expiryDate.isAfter(cutoff))
                    .toList()
              : allItems;
          if (items.isEmpty && allItems.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Nothing needs attention in the next three days.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ExperiencePreferences.instance
                          .setInteger('pantryView', 0),
                      child: const Text('Show all food'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (items.isEmpty) return _emptyState(context, ref, textTheme);
          final mostUrgent = items.first;
          return ListView(
            children: [
              HeroEatFirstCard(
                item: mostUrgent,
                onUsedUp: () async {
                  await ref
                      .read(itemsProvider.notifier)
                      .removeItem(mostUrgent.id);
                  if (context.mounted) {
                    _showUndoSnack(context, ref, 'Marked as used up');
                  }
                },
                onTap: () => _openEditSheet(context, ref, mostUrgent),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  filter == 1 ? 'Eat within 3 days (${items.length})' : 'All items (${items.length})',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final item in items)
                Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: EatSoonColors.tomato,
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) async {
                    await ref.read(itemsProvider.notifier).removeItem(item.id);
                    if (context.mounted) {
                      _showUndoSnack(context, ref, 'Removed ${item.name}');
                    }
                  },
                  child: FoodListRow(
                    item: item,
                    onTap: () => _openEditSheet(context, ref, item),
                  ),
                ),
              if (!canAddMore)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'You\u2019ve reached 5 items on the free plan.',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Upgrade to Pro',
                            onPressed: () => _openPaywall(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context, ref),
        backgroundColor: EatSoonColors.tomato,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/onboarding_2.webp',
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text('Nothing tracked yet', style: textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Add your groceries and EatSoon will tell you what to eat first.',
              style: textTheme.bodyLarge?.copyWith(
                color: EatSoonColors.inkMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Add your first item',
              onPressed: () => _openAddSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
