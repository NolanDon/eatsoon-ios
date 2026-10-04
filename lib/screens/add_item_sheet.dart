import 'package:eatsoon/logic/expiry_logic.dart';
import 'package:eatsoon/models/food_item.dart';
import 'package:eatsoon/state/providers.dart';
import 'package:eatsoon/theme.dart';
import 'package:eatsoon/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Pop result of the sheet.
enum AddItemResult { saved, usedUp, limitReached, cancelled }

/// Bottom sheet for adding (or editing) a food item.
class AddItemSheet extends ConsumerStatefulWidget {
  const AddItemSheet({super.key, this.item});

  /// When non-null, the sheet edits this item instead of creating one.
  final FoodItem? item;

  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  final _nameController = TextEditingController();
  late FoodCategory _category;
  late DateTime _expiryDate;
  String? _nameError;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController.text = item?.name ?? '';
    _category = item?.category ?? FoodCategory.produce;
    final now = DateTime.now();
    _expiryDate = item?.expiryDate ??
        DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _save() async {
    final error = FoodItem.validateName(_nameController.text);
    setState(() => _nameError = error);
    if (error != null) return;
    setState(() => _saving = true);

    final notifier = ref.read(itemsProvider.notifier);
    if (_isEdit) {
      await notifier.updateItem(
        widget.item!.copyWith(
          name: _nameController.text.trim(),
          category: _category,
          expiryDate: _expiryDate,
        ),
      );
    } else {
      final ok = await notifier.addItem(
        FoodItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          category: _category,
          expiryDate: _expiryDate,
        ),
      );
      if (!ok && mounted) {
        Navigator.of(context).pop(AddItemResult.limitReached);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(AddItemResult.saved);
  }

  Future<void> _usedUp() async {
    if (!_isEdit) return;
    await ref.read(itemsProvider.notifier).removeItem(widget.item!.id);
    if (mounted) Navigator.of(context).pop(AddItemResult.usedUp);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(_expiryDate);
    final days = daysUntilExpiry(_expiryDate, DateTime.now());

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: EatSoonColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEdit ? 'Edit item' : 'Add item',
                style: textTheme.headlineLarge?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'What is it?',
                  hintText: 'Milk, chicken thighs, spinach\u2026',
                  errorText: _nameError,
                ),
                textInputAction: TextInputAction.done,
                maxLength: 60,
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text('Category', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FoodCategory.values.map((c) {
                  final selected = c == _category;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(c.label),
                      ],
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: EatSoonColors.tomatoTint,
                    labelStyle: TextStyle(
                      color: selected
                          ? EatSoonColors.tomato
                          : EatSoonColors.ink,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: selected
                          ? EatSoonColors.tomato
                          : EatSoonColors.divider,
                    ),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Expires', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EatSoonColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: EatSoonColors.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(dateLabel, style: textTheme.bodyLarge),
                      ),
                      Text(
                        daysLeftLabel(days),
                        style: textTheme.bodyMedium?.copyWith(
                          color: urgencyColor(urgencyForDays(days)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isEdit ? 'Save changes' : 'Add item',
                onPressed: _save,
                isLoading: _saving,
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _usedUp,
                    child: const Text('Used up — remove it'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
