import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'experience_preferences.dart';

const appName = "EatSoon";
const preferenceTitle = "Pantry view";
const preferenceKey = "pantryView";
const workflowTitle = "Plan dinner from what you have";
const workflowBody =
    "Use the eat-soon view to see what needs attention over the next three days. Your freshest food stays safely in the full pantry.";
const setupTitle = "A pantry that works for you";
const setupBody =
    "Choose your everyday view. Switch back to the full pantry any time from Settings.";
const appStoreId = String.fromEnvironment('APP_STORE_ID', defaultValue: '');
const preferenceDefault = 0;
const preferenceOptions = <int, String>{0: "All food", 1: "Eat within 3 days"};
const practicalTips = <String>[
  "Check the label and condition of food; the date tracker does not determine whether food is safe.",
  "Mark food as used up when you finish it. Use Undo if you remove the wrong item.",
  "The three-day view includes overdue items so they do not disappear from attention.",
];
int currentAppPreference(WidgetRef ref) =>
    ExperiencePreferences.instance.integer(preferenceKey, preferenceDefault);
Future<void> saveAppPreference(int value, WidgetRef ref) =>
    ExperiencePreferences.instance.setInteger(preferenceKey, value);
