import 'package:eatsoon/logic/expiry_logic.dart';
import 'package:eatsoon/models/food_item.dart';
import 'package:eatsoon/theme.dart';
import 'package:flutter/material.dart';

/// One row in the food list: icon, name/category, days-left label,
/// and a colored urgency bar on the left edge.
class FoodListRow extends StatelessWidget {
  const FoodListRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  final FoodItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = daysUntilExpiry(item.expiryDate, now);
    final urgency = urgencyForDays(days);
    final color = urgencyColor(urgency);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(12),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: urgencyTint(urgency),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.category.icon, color: color, size: 24),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category.label,
                        style: textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  daysLeftLabel(days),
                  style: textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
