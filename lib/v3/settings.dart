import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../experience/experience_preferences.dart';
import '../experience/feedback_form.dart';
import '../experience/feedback_service.dart';
import 'brand.dart';
import 'mascot.dart';
import 'widgets.dart';

class AppSettings extends StatefulWidget {
  final SharedPreferences prefs;
  final Future<void> Function() plans,
      copyBackup,
      restore,
      oldRecords,
      reminders;
  final VoidCallback replay;
  const AppSettings({
    super.key,
    required this.prefs,
    required this.plans,
    required this.copyBackup,
    required this.restore,
    required this.oldRecords,
    required this.reminders,
    required this.replay,
  });
  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  String get profile =>
      widget.prefs.getString('v3.$appId.profile') ?? 'Your profile';
  Future<void> editProfile() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ProfileEditor(initial: profile == 'Your profile' ? '' : profile),
    );
    if (value == null) return;
    if (value.isEmpty) {
      await widget.prefs.remove('v3.$appId.profile');
    } else {
      await widget.prefs.setString('v3.$appId.profile', value);
    }
    if (mounted) setState(() {});
  }

  Future<void> openLink(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) notice(context, 'Could not open this link. Please try again.');
  }

  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: ink.withValues(alpha: .3)),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget row(
    String title,
    IconData icon,
    VoidCallback action, {
    String? subtitle,
  }) {
    final upgrade = title == 'Upgrade';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: upgrade
            ? ink
            : Color.alphaBlend(accent.withValues(alpha: .22), paper),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          minVerticalPadding: 14,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ink.withValues(alpha: .24)),
          ),
          leading: upgrade ? null : Icon(icon, color: ink),
          title: Text(
            title,
            style: TextStyle(
              color: upgrade ? Colors.white : ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: upgrade ? Colors.white : ink,
          ),
          onTap: action,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final choices = ExperiencePreferences.instance;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            MainTitle(
              'Settings',
              trailing: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      const Mascot(pose: 'welcome', height: 64),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text('Local profile'),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        onPressed: editProfile,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  section('Membership'),
                  row('Upgrade', Icons.diamond_outlined, () => widget.plans()),
                  row(
                    'Manage subscriptions',
                    Icons.subscriptions_outlined,
                    () => openLink(
                      defaultTargetPlatform == TargetPlatform.android
                          ? 'https://play.google.com/store/account/subscriptions'
                          : 'https://apps.apple.com/account/subscriptions',
                    ),
                  ),
                  row(
                    'Food scanning guide',
                    Icons.auto_stories_outlined,
                    () {
                      Navigator.pop(context);
                      widget.replay();
                    },
                  ),
                  if ([
                    'fridge',
                    'plant',
                    'maintenance',
                    'goal',
                  ].contains(appKind))
                    row(
                      'Food check reminders',
                      Icons.notifications_none,
                      () => widget.reminders(),
                    ),
                  section('Preferences'),
                  const CorePreferences(),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: choices,
                    builder: (context, _) => Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          title: const Text('Reduce motion'),
                          value: choices.flag('reduceMotion', fallback: false),
                          onChanged: (v) => choices.setFlag('reduceMotion', v),
                        ),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          title: const Text('Touch feedback'),
                          value: choices.flag('haptics'),
                          onChanged: (v) => choices.setFlag('haptics', v),
                        ),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          title: const Text('Occasional review requests'),
                          value: choices.flag('reviewRequests'),
                          onChanged: (v) =>
                              choices.setFlag('reviewRequests', v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  section('Your data'),
                  row(
                    'Copy kitchen backup',
                    Icons.copy_outlined,
                    () => widget.copyBackup(),
                  ),
                  row(
                    'Recover my kitchen',
                    Icons.restore,
                    () => widget.restore(),
                  ),
                  row(
                    'Earlier food lists',
                    Icons.history,
                    () => widget.oldRecords(),
                  ),
                  const SizedBox(height: 12),
                  section('Help and legal'),
                  row(
                    'Support',
                    Icons.support_agent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportScreen()),
                    ),
                  ),
                  row(
                    'Privacy',
                    Icons.privacy_tip_outlined,
                    () => openLink(AppConfig.privacyUrl),
                  ),
                  row(
                    'Terms',
                    Icons.description_outlined,
                    () => openLink(AppConfig.termsUrl),
                  ),
                  row(
                    'About and licenses',
                    Icons.info_outline,
                    () => showLicensePage(
                      context: context,
                      applicationName: appName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '$appName · Your records stay on this device.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          MainTitle(
            'Support',
            trailing: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const FeedbackForm(send: sendFeedback),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: 'support@boxillapps.com'),
                    );
                    if (context.mounted) {
                      notice(context, 'Support address copied.');
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy support email'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileEditor extends StatefulWidget {
  final String initial;
  const _ProfileEditor({required this.initial});
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your local profile'),
    content: TextField(
      controller: input,
      maxLength: 40,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Name or nickname',
        helperText: 'Saved on this device. No account needed.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, input.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}

class CorePreferences extends StatelessWidget {
  const CorePreferences({super.key});
  @override
  Widget build(BuildContext context) {
    final specification = switch (appKind) {
      'meal' => (
        'Quantity display',
        'quantityFormat',
        0,
        <int, String>{0: 'Smart fractions', 1: 'Decimals'},
      ),
      'plant' => (
        'Soil check interval',
        'wateringDays',
        7,
        <int, String>{3: '3 days', 7: '7 days', 14: '14 days'},
      ),
      'fridge' => (
        'Food list',
        'pantryView',
        0,
        <int, String>{0: 'All food', 1: 'Check within 3 days'},
      ),
      'maintenance' => (
        'Service list order',
        'garageOrder',
        0,
        <int, String>{0: 'Service date', 1: 'Vehicle name'},
      ),
      _ => null,
    };
    if (specification == null) return const SizedBox.shrink();
    final pref = ExperiencePreferences.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ListenableBuilder(
        listenable: pref,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              specification.$1,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in specification.$4.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected:
                        pref.integer(specification.$2, specification.$3) ==
                        entry.key,
                    onSelected: (v) {
                      if (v) pref.setInteger(specification.$2, entry.key);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BackupRestoreDialog extends StatefulWidget {
  const BackupRestoreDialog({super.key});
  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Restore backup'),
    content: TextField(
      controller: input,
      minLines: 3,
      maxLines: 6,
      decoration: const InputDecoration(
        hintText: 'Paste your version 3 backup',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, input.text),
        child: const Text('Review'),
      ),
    ],
  );
}
