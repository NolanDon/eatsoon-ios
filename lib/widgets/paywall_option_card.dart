import 'package:eatsoon/services/revenuecat_service.dart';
import 'package:eatsoon/theme.dart';
import 'package:flutter/material.dart';

/// One selectable subscription option on the paywall.
/// Selected state: 2pt primary border + light tint fill. Solid colors only.
class PaywallOptionCard extends StatelessWidget {
  const PaywallOptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PaywallOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? EatSoonColors.tomatoTint : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? EatSoonColors.tomato : EatSoonColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? EatSoonColors.tomato
                      : EatSoonColors.inkMuted,
                  width: 2,
                ),
                color: selected ? EatSoonColors.tomato : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        option.title,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (option.bestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: EatSoonColors.tomato,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Best value',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.trialText,
                    style: textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Text(
              option.priceString,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
