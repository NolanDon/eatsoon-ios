import 'dart:convert';

import '../experience/review_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';
import 'actions.dart';
import 'brand.dart';
import 'dashboard.dart';
import 'editor.dart';
import 'model.dart';
import 'mascot.dart';
import 'legacy.dart';
import 'paywall.dart';
import 'photo_flow.dart';
import 'widgets.dart';
import 'onboarding.dart';
import 'settings.dart';
import 'sharing.dart';

class V3Home extends StatefulWidget {
  const V3Home({super.key});
  @override
  State<V3Home> createState() => _HomeState();
}

class _HomeState extends State<V3Home> {
  V3Store? store;
  SharedPreferences? prefs;
  String directory = '';
  bool busy = false, isPro = false;
  int introduction = -1;
  String? error;
  bool justSaved = false;
  bool showingWizard = false;
  final dashboardKey = GlobalKey<DashboardState>();
  final shareKey = GlobalKey();
  int get freeLimit => switch (appKind) {
    'clothing' => 12,
    'fridge' => 20,
    'ticket' => 5,
    'maintenance' => 5,
    _ => 3,
  };
  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      String path = '';
      try {
        path = await vision.invokeMethod<String>('directory') ?? '';
      } catch (_) {}
      if (!mounted) return;
      final data = V3Store(appId, appKind, preferences);
      data.addListener(refresh);
      setState(() {
        prefs = preferences;
        directory = path;
        store = data;
        isPro = preferences.getBool('v3.$appId.pro') ?? false;
        introduction = preferences.getBool('v3.$appId.intro') == true
            ? 3
            : data.items.isEmpty
            ? 0
            : 2;
      });
      refreshPro();
      if (introduction == 3 &&
          preferences.getBool('v3.$appId.wizard') != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => wizard());
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not open saved data.');
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> refreshPro() async {
    try {
      await ensureBilling();
      final info = await Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 10),
      );
      final active =
          info.entitlements.all[AppConfig.entitlementId]?.isActive == true;
      await prefs?.setBool('v3.$appId.pro', active);
      if (mounted) setState(() => isPro = active);
    } catch (_) {}
  }

  Future<void> paywall() async {
    final unlocked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const V3Paywall()),
    );
    if (unlocked == true) {
      await prefs?.setBool('v3.$appId.pro', true);
      if (mounted) setState(() => isPro = true);
    }
  }

  Future<void> saveNew(List<Item> values) async {
    need(
      isPro ||
          store!.items.length +
                  values
                      .where((v) => !store!.items.any((e) => sameFood(e, v)))
                      .fold<List<Item>>([], (unique, v) {
                        if (!unique.any((e) => sameFood(e, v))) unique.add(v);
                        return unique;
                      })
                      .length <=
              freeLimit,
      'Choose up to $freeLimit items in the free collection, or use Plus.',
    );
    final before = store!.items.length;
    await store!.addAll(values);
    if (mounted && store!.items.length == before)
      notice(context, 'Already in your kitchen. No duplicates added.');
    if (mounted) {
      setState(() => justSaved = true);
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => justSaved = false);
      });
    }
    for (final item in store!.items) {
      await schedule(item);
    }
  }

  @override
  void dispose() {
    store?.removeListener(refresh);
    store?.dispose();
    super.dispose();
  }

  void considerPhotoReview() {
    if (prefs?.getBool('v3.$appId.photoSuccess') != true) return;
    ReviewService.firstPhotoSuccess(
      canPrompt: () =>
          mounted &&
          !busy &&
          !showingWizard &&
          introduction == 3 &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );
  }

  Future<void> create({String? source}) async {
    if (busy) return;
    if (!isPro && store!.items.length >= freeLimit && appKind != 'fridge') {
      await paywall();
      if (!isPro || !mounted) return;
    }
    final chosen =
        source ??
        await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          builder: (sheet) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Add food to your fridge",
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                MainAction(
                  'Scan food',
                  () => Navigator.pop(sheet, 'camera'),
                  icon: Icons.document_scanner_outlined,
                  fontSize: 18,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    textStyle: Theme.of(sheet).textTheme.bodyLarge
                        ?.copyWith(fontSize: 18),
                  ),
                  onPressed: () => Navigator.pop(sheet, 'photos'),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick a food photo'),
                ),
                if (appKind != 'clothing' &&
                    appKind != 'drawing' &&
                    introduction == 3)
                  TextButton(
                    onPressed: () => Navigator.pop(sheet, 'manual'),
                    child: const Text('Type food details'),
                  ),
              ],
            ),
          ),
        );
    if (chosen == null || !mounted) return;
    setState(() => busy = true);
    final countBefore = store!.items.length;
    List<Item>? drafts;
    try {
      if (chosen == 'manual') {
        final value = await editItem(context, directory: directory);
        if (value != null) {
          await saveNew([value]);
        }
      } else {
        final values = await readPhoto(context, directory, source: chosen);
        drafts = values;
        if (values == null || !mounted) return;
        if (appKind == 'fridge' && values.length > 1) {
          final checked = await Navigator.push<List<Item>>(
            context,
            MaterialPageRoute(builder: (_) => _FoodReview(values: values)),
          );
          if (checked != null && checked.isNotEmpty) await saveNew(checked);
        } else {
          final edited = await editItem(
            context,
            value: values.first,
            directory: directory,
          );
          if (edited != null) await saveNew([edited]);
        }
      }
      if (mounted && introduction < 2 && store!.items.isNotEmpty) {
        setState(() => introduction = 2);
      }
    } catch (e) {
      if (mounted) {
        notice(context, e is FormatException ? e.message : 'Could not save.');
      }
    } finally {
      if (drafts != null) await cleanPhotos(drafts);
      if (drafts != null && store!.items.length > countBefore) {
        await prefs?.setBool('v3.$appId.photoSuccess', true);
      }
      if (mounted) {
        setState(() => busy = false);
        considerPhotoReview();
      }
    }
  }

  Future<void> edit(Item value) async {
    final result = await editItem(context, value: value, directory: directory);
    if (result != null) await update(result);
  }

  Future<void> update(Item value) async {
    try {
      await store!.update(value);
      await schedule(value);
    } catch (e) {
      if (mounted) {
        notice(context, e is FormatException ? e.message : 'Could not save.');
      }
    }
  }

  Future<void> remove(Item value) async {
    if (!await confirm(
      context,
      'Delete this item?',
      'Saved records cannot be undone.',
      action: 'Delete',
    )) {
      return;
    }
    try {
      await store!.remove(value['id'] as String);
      await cleanPhotos([value]);
      try {
        await vision.invokeMethod('clearReminder', {'id': value['id']});
      } catch (_) {}
    } catch (_) {
      if (mounted) notice(context, 'Could not delete.');
    }
  }

  Future<void> cleanPhotos(List<Item> values) async {
    final used = {
      for (final item in store!.items)
        for (final key in ['photo', 'cutout'])
          if (item[key] != null) item[key] as String,
    };
    final unused = {
      for (final item in values)
        for (final key in ['photo', 'cutout'])
          if (item[key] != null && !used.contains(item[key]))
            item[key] as String,
    };
    for (final file in unused) {
      try {
        await vision.invokeMethod('removePhoto', {'file': file});
      } catch (_) {}
    }
  }

  Future<void> importedShared(bool enableReminders) async {
    if (mounted && introduction < 2 && store!.items.isNotEmpty) {
      setState(() => introduction = 2);
    }
    if (enableReminders &&
        prefs?.getBool('v3.$appId.reminders') != true &&
        mounted) {
      final allow = await showDialog<bool>(
        context: context,
        builder: (sheet) => AlertDialog(
          title: const Text('Keep these reminders?'),
          content: const Text(
            'Your shared dates are saved. Allow notifications to receive the same reminders at 9 AM local time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(sheet, false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(sheet, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      if (allow == true) await reminders();
    }
    for (final item in store!.items) {
      await schedule(item);
    }
  }

  Future<void> reminders() async {
    final scheduled = store!.items
        .where(
          (v) =>
              v['nextDate'] != null ||
              v['nextServiceDate'] != null ||
              v['deadline'] != null,
        )
        .toList();
    if (scheduled.isEmpty) {
      if (mounted) notice(context, 'Add a check or service date first.');
      return;
    }
    try {
      final granted =
          await vision.invokeMethod<bool>('reminderPermission') ?? false;
      if (!granted) {
        if (mounted) {
          notice(
            context,
            'Notifications are off. Dates stay on your dashboard.',
          );
        }
        return;
      }
      await prefs!.setBool('v3.$appId.reminders', true);
      for (final item in scheduled) {
        final enabled = {...item, 'sharedReminders': true};
        if (item['sharedReminders'] == false) await store!.update(enabled);
        await schedule(enabled);
      }
      if (mounted) notice(context, 'Reminders enabled.');
    } catch (_) {
      if (mounted) notice(context, 'Reminders are unavailable here.');
    }
  }

  Future<void> schedule(Item item) async {
    if (item['sharedReminders'] == false) {
      try {
        await vision.invokeMethod('clearReminder', {'id': item['id']});
      } catch (_) {}
      return;
    }
    if (appKind == 'fridge' && item['used'] == true) {
      try {
        await vision.invokeMethod('clearReminder', {'id': item['id']});
      } catch (_) {}
      return;
    }
    if (prefs?.getBool('v3.$appId.reminders') != true) return;
    try {
      final at = dateOrNull(
        item['nextDate'] ?? item['nextServiceDate'] ?? item['deadline'],
      );
      if (at == null) return;
      await vision.invokeMethod('setReminder', {
        'id': item['id'],
        'date': day(at),
        'title': appName,
        'body': switch (appKind) {
          'plant' => 'Check the soil for ${item['name']}.',
          'fridge' => 'Check the label for ${item['name']}.',
          'maintenance' => 'Review the next service for ${item['vehicle']}.',
          _ => 'Check in on ${item['name']}.',
        },
      });
    } catch (_) {}
  }

  Future<void> finish() async {
    if (busy) return;
    if (!isPro && store!.items.isNotEmpty) await paywall();
    if (!mounted) return;
    await prefs!.setBool('v3.$appId.intro', true);
    if (!mounted) return;
    setState(() => introduction = 3);
    WidgetsBinding.instance.addPostFrameCallback((_) => wizard());
  }

  Future<void> wizard() async {
    if (!mounted ||
        prefs == null ||
        prefs!.getBool('v3.$appId.wizard') == true) {
      return;
    }
    final next = switch (appKind) {
      'clothing' => 'Add a top and bottoms, then build your first outfit.',
      'fridge' => 'Check the detected items and dates.',
      'plant' => 'Choose a soil-check rhythm for your plant.',
      'meal' => 'Open a recipe and choose your servings.',
      'knitting' => 'Open your pattern and follow one row.',
      'furniture' => 'Enter measured item and doorway sizes.',
      'drawing' => 'Open your comic and make each panel yours.',
      'ticket' => 'Open a ticket and add your memory.',
      'maintenance' => 'Record your vehicle and next service date.',
      'goal' => 'Choose a goal, then plan your next payday.',
      _ => '',
    };
    setState(() => showingWizard = true);
    final done = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Mascot(pose: 'guide', height: 150)),
              const SizedBox(height: 12),
              Text(
                'Your next step',
                style: Theme.of(sheet).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(next),
              const SizedBox(height: 22),
              MainAction(
                'Show me',
                () => Navigator.pop(sheet, true),
                icon: Icons.arrow_forward,
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: const Text('Later'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => showingWizard = false);
    considerPhotoReview();
    await prefs!.setBool('v3.$appId.wizard', true);
    if (done == true && mounted) {
      if (store!.items.isEmpty) {
        await create();
      } else {
        dashboardKey.currentState?.startFirst();
      }
    }
  }

  Future<void> settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppSettings(
          prefs: prefs!,
          plans: paywall,
          restore: restore,
          oldRecords: oldRecords,
          reminders: reminders,
          copyBackup: () async {
            await Clipboard.setData(ClipboardData(text: store!.export()));
            if (mounted) notice(context, 'Backup copied.');
          },
          replay: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (page) => Scaffold(
                body: SafeArea(
                  child: FeatureOnboarding(onDone: () => Navigator.pop(page)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> restore() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const BackupRestoreDialog(),
    );
    if (text == null || !mounted) return;
    try {
      store!.decode(text);
      if (await confirm(
        context,
        'Replace current records?',
        'Copy a backup first if you want to keep both.',
        action: 'Restore',
      )) {
        if (store!.recovery != null) {
          await store!.recover(text);
        } else {
          await store!.restore(text);
        }
      }
    } catch (e) {
      if (mounted) {
        notice(context, e is FormatException ? e.message : 'Invalid backup.');
      }
    }
  }

  Future<void> oldRecords() async {
    final keys =
        prefs!
            .getKeys()
            .where(
              (key) =>
                  !key.startsWith('v3.') &&
                  (key.contains(appId) || key.contains(apiAppId)),
            )
            .toList()
          ..sort();
    final records = <Item>[];
    for (final key in keys) {
      try {
        final raw = prefs!.get(key);
        if (raw is! String) continue;
        final value = jsonDecode(raw);
        final values = value is List
            ? value
            : value is Map && value['records'] is List
            ? value['records'] as List
            : value is Map && value['sessions'] is List
            ? value['sessions'] as List
            : value is Map
            ? [value]
            : const [];
        for (final entry in values) {
          if (entry is Map) records.add(Map<String, dynamic>.from(entry));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (page) => Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                MainTitle(
                  'Previous records',
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(page),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: records.isEmpty
                      ? const EmptyView(
                          'No earlier records',
                          'Your version 3 items are on the dashboard.',
                          Icons.history,
                        )
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, i) => const Divider(),
                          itemBuilder: (_, i) => ListTile(
                            title: Text(
                              (records[i]['name'] ??
                                      records[i]['title'] ??
                                      'Saved record')
                                  .toString(),
                            ),
                            onTap: () async {
                              try {
                                final draft = legacyDraft(appKind, records[i]);
                                if (draft == null) {
                                  notice(
                                    page,
                                    'Copy this record to keep its full details.',
                                  );
                                  return;
                                }
                                final checked = await editItem(
                                  page,
                                  value: draft,
                                  directory: directory,
                                );
                                if (checked != null) {
                                  await saveNew([checked]);
                                  if (page.mounted) {
                                    notice(page, 'Imported. Original kept.');
                                  }
                                }
                              } catch (_) {
                                if (page.mounted) {
                                  notice(
                                    page,
                                    'Copy this record to keep its full details.',
                                  );
                                }
                              }
                            },
                            trailing: IconButton(
                              tooltip: 'Copy record',
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: const JsonEncoder.withIndent('  ')
                                        .convert(records[i]),
                                  ),
                                );
                                if (page.mounted) {
                                  notice(page, 'Record copied.');
                                }
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyView('Could not open', error!, Icons.error_outline),
        ),
      );
    }
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (store!.recovery != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const MainTitle('Recover your data'),
              const Expanded(
                child: EmptyView(
                  'Saved data is protected',
                  'Copy the original before recovering.',
                  Icons.lock_outline,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: MainAction('Copy original', () async {
                  await Clipboard.setData(
                    ClipboardData(text: prefs!.getString(store!.key) ?? ''),
                  );
                  if (context.mounted) notice(context, 'Original copied.');
                }, icon: Icons.copy),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: OutlinedButton(
                  onPressed: restore,
                  child: const Text('Restore a valid backup'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final actions = DashboardActions(
      store: store!,
      directory: directory,
      add: () => create(),
      edit: edit,
      remove: remove,
      update: update,
    );
    final dashboard = Dashboard(key: dashboardKey, actions: actions);
    if (introduction == 0) {
      return Scaffold(
        body: SafeArea(
          child: FeatureOnboarding(
            onDone: () => setState(() => introduction = 1),
          ),
        ),
      );
    }
    if (introduction < 2) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              MainTitle(
                appName,
                centered: true,
                trailing: TextButton(
                  onPressed: busy ? null : finish,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    minimumSize: const Size(0, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Skip', maxLines: 1, softWrap: false),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 20),
                    Mascot(
                      pose: introduction == 0 ? 'welcome' : 'guide',
                      height: 150,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      appTagline,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      introduction == 0
                          ? 'Make something useful before choosing a plan.'
                          : photoInstruction,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (busy || justSaved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    children: [
                      Mascot(pose: busy ? 'thinking' : 'success', height: 56),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          busy
                              ? 'Analyzing your photo. Please keep the app open.'
                              : 'Stock my kitchen',
                        ),
                      ),
                      if (busy) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: MainAction(
                  introduction == 0 ? 'Get started' : 'Scan food',
                  busy
                      ? null
                      : () => introduction == 0
                            ? setState(() => introduction = 1)
                            : create(source: 'camera'),
                  icon: introduction == 0
                      ? Icons.arrow_forward
                      : Icons.document_scanner_outlined,
                ),
              ),
              if (introduction == 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: busy ? null : () => create(source: 'photos'),
                      child: const Text('Pick a food photo'),
                    ),
                  ),
                ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => showSharing(
                        context,
                        store!,
                        directory,
                        onImported: importedShared,
                        initialTab: 1,
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                ),
                child: const Text('Have a share code?'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            MainTitle(
              appName,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Share kitchen list',
                    onPressed: busy
                        ? null
                        : () => showSharing(
                            context,
                            store!,
                            directory,
                            onImported: importedShared,
                          ),
                    icon: const Icon(Icons.playlist_add),
                  ),
                  IconButton(
                    tooltip: 'Kitchen settings',
                    onPressed: settings,
                    icon: const Icon(Icons.kitchen_outlined),
                  ),
                ],
              ),
            ),
            if (!showingWizard && (busy || justSaved))
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Mascot(pose: busy ? 'thinking' : 'success', height: 76),
                  const SizedBox(width: 8),
                  Text(busy ? 'Looking closely' : 'Stock my kitchen'),
                ],
              ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: Opacity(
                opacity: showingWizard ? 0 : 1,
                child: RepaintBoundary(
                  key: shareKey,
                  child: ColoredBox(color: paper, child: dashboard),
                ),
              ),
            ),
            if (introduction == 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: MainAction(
                  'Continue',
                  finish,
                  icon: Icons.arrow_forward,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FoodReview extends StatefulWidget {
  final List<Item> values;
  const _FoodReview({required this.values});
  @override
  State<_FoodReview> createState() => _FoodReviewState();
}

class _FoodReviewState extends State<_FoodReview> {
  late final selected = List.filled(widget.values.length, true);
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const MainTitle('Check your food'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('Dates are estimates unless read from a label.'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.values.length,
              itemBuilder: (_, i) {
                final item = widget.values[i];
                return CheckboxListTile(
                  value: selected[i],
                  onChanged: (v) => setState(() => selected[i] = v ?? false),
                  title: Text(item['name'] as String),
                  subtitle: Text(
                    item['labelDate'] == null
                        ? 'Check in ${item['checkDays']} days'
                        : 'Label: ${item['labelDate']}',
                  ),
                  secondary: IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final value = await editItem(context, value: item);
                      if (value != null && mounted) {
                        setState(() => widget.values[i] = value);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: MainAction(
              'Add ${selected.where((v) => v).length} items',
              selected.any((v) => v)
                  ? () => Navigator.pop(context, [
                      for (var i = 0; i < selected.length; i++)
                        if (selected[i]) widget.values[i],
                    ])
                  : null,
              icon: Icons.check,
            ),
          ),
        ],
      ),
    ),
  );
}
