import 'package:flutter/material.dart';
import '../v3/paywall.dart';
class PaywallScreen extends StatelessWidget {
 const PaywallScreen({super.key, required this.onDone});
 final ValueChanged<bool> onDone;
 @override Widget build(BuildContext context) => V3Paywall(onComplete: onDone);
}
