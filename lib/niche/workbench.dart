import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journal.dart';
import 'draft.dart';

class EntryField {
  final String key, label, initial;
  final double? min, max;
  final bool whole, optional, multiline, date;
  final List<String>? options;
  const EntryField(
    this.key,
    this.label, {
    this.initial = '',
    this.min,
    this.max,
    this.whole = false,
    this.optional = false,
    this.multiline = false,
    this.date = false,
    this.options,
  });
}

Future<Record?> editEntry(
  BuildContext context,
  String title,
  List<EntryField> fields, {
  DraftContext? draft,
}) => showModalBottomSheet<Record>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _Editor(title: title, fields: fields, draft: draft),
);

class _Editor extends StatefulWidget {
  final String title;
  final List<EntryField> fields;
  final DraftContext? draft;
  const _Editor({required this.title, required this.fields, this.draft});
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(
        text: f.initial.isEmpty && f.options != null
            ? f.options!.first
            : f.initial,
      ),
  };
  bool drafting = false;
  int draftRevision = 0;
  Future<void> extractDraft() async {
    final source = await editEntry(
      context,
      'Extract from your own notes',
      const [
        EntryField(
          'notes',
          'Paste source text · no sensitive details',
          multiline: true,
        ),
      ],
    );
    if (source == null || !mounted) return;
    setState(() => drafting = true);
    try {
      final values = await widget.draft!.extract(
        context,
        source['notes'] as String,
      );
      if (values == null || !mounted) return;
      final allowed = widget.fields.map((f) => f.key).toSet();
      check(
        values.keys.every(allowed.contains),
        'The draft contained unexpected fields. Enter the values manually.',
      );
      for (final f in widget.fields) {
        final value = values[f.key];
        check(
          value == null || value is String || value is num,
          'The draft contained an unreadable field.',
        );
        if (value is num) {
          check(value.isFinite, 'The draft contained an invalid number.');
        }
      }
      setState(() {
        for (final f in widget.fields) {
          controllers[f.key]!.text = values[f.key]?.toString() ?? '';
        }
        draftRevision++;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Draft loaded. Check every value and fill missing fields before saving.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is FormatException ? e.message : '$e')),
        );
      }
    } finally {
      if (mounted) setState(() => drafting = false);
    }
  }

  String? validateField(EntryField f, String raw) {
    final s = raw.trim();
    if (s.isEmpty) return f.optional ? null : 'Enter ${f.label.toLowerCase()}.';
    if (f.options != null && !f.options!.contains(s)) {
      return 'Choose ${f.label.toLowerCase()}.';
    }
    if (s.length >
        (f.key == 'backup'
            ? 4000000
            : f.multiline
            ? 4000
            : 120)) {
      return '${f.label} is too long.';
    }
    if (f.date) {
      final parsed = DateTime.tryParse(s);
      if (parsed == null || dayText(parsed) != s) return 'Choose a valid date.';
    }
    if (f.min != null) {
      final n = double.tryParse(s);
      if (n == null || !n.isFinite || n < f.min! || n > (f.max ?? 1000000)) {
        return 'Enter ${f.label.toLowerCase()} within ${f.min}–${f.max ?? 1000000}.';
      }
      if (f.whole && n != n.roundToDouble()) {
        return '${f.label} must be a whole number.';
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('entry-scroll'),
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (widget.draft != null)
                    OutlinedButton.icon(
                      onPressed: drafting ? null : extractDraft,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        drafting ? 'Extracting…' : 'Draft from my notes',
                      ),
                    ),
                  if (drafting) const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  for (final f in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: f.options != null
                          ? DropdownButtonFormField<String>(
                              key: ValueKey('${f.key}-$draftRevision'),
                              initialValue:
                                  f.options!.contains(controllers[f.key]!.text)
                                  ? controllers[f.key]!.text
                                  : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: f.label,
                                border: const OutlineInputBorder(),
                              ),
                              items: f.options!
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              validator: (value) => value == null
                                  ? 'Choose ${f.label.toLowerCase()}.'
                                  : null,
                              onChanged: (v) => controllers[f.key]!.text = v!,
                            )
                          : TextFormField(
                              key: ValueKey('field-${f.key}'),
                              controller: controllers[f.key],
                              minLines: f.multiline ? 3 : 1,
                              maxLines: f.multiline ? 6 : 1,
                              maxLength: f.key == 'backup'
                                  ? 4000000
                                  : f.multiline
                                  ? 4000
                                  : 120,
                              readOnly: f.date,
                              keyboardType: f.min != null
                                  ? TextInputType.numberWithOptions(
                                      decimal: !f.whole,
                                      signed: f.min! < 0,
                                    )
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                labelText: f.label,
                                border: const OutlineInputBorder(),
                                suffixIcon: f.date
                                    ? const Icon(Icons.calendar_today)
                                    : null,
                              ),
                              onTap: !f.date
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            DateTime.tryParse(
                                              controllers[f.key]!.text,
                                            ) ??
                                            DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        controllers[f.key]!.text = dayText(
                                          picked,
                                        );
                                      }
                                    },
                              validator: (raw) => validateField(f, raw ?? ''),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: drafting
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      final visibleValid = form.currentState!.validate();
                      for (final f in widget.fields) {
                        final error = validateField(
                          f,
                          controllers[f.key]!.text,
                        );
                        if (error != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }
                      }
                      if (!visibleValid) return;
                      final values = <String, dynamic>{};
                      for (final f in widget.fields) {
                        final s = controllers[f.key]!.text.trim();
                        values[f.key] = f.min == null
                            ? s
                            : f.whole
                            ? num.parse(s).toInt()
                            : double.parse(s);
                      }
                      Navigator.of(context).pop(values);
                    },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}

abstract class WorkbenchState<T extends StatefulWidget> extends State<T> {
  String get app;
  void validate(Record record);
  JournalStore? store;
  List<Record> records = [];
  bool busy = false;
  String? loadError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = JournalStore(app, validate, prefs);
      store = s;
      final data = s.read();
      if (mounted) {
        setState(() {
          store = s;
          records = data;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => loadError = 'Saved data could not be read. It has been preserved. Restore from a verified backup before adding records.',
        );
      }
    }
  }

  Future<void> commit(void Function(List<Record>) mutation) async {
    if (store == null || busy) return;
    setState(() => busy = true);
    try {
      final data = await store!.change(mutation);
      if (mounted) setState(() => records = data);
    } catch (e) {
      if (mounted) {
        message(
          e is FormatException
              ? e.message
              : 'Could not save. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> update(Record record) => commit((all) {
    final i = all.indexWhere((e) => e['id'] == record['id']);
    if (i >= 0) {
      all[i] = record;
    } else {
      all.add(record);
    }
  });
  Future<void> remove(Record r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${r['name']}?'),
        content: const Text(
          'Its local entries will also be deleted. Copy a backup first if you need them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await commit((all) => all.removeWhere((e) => e['id'] == r['id']));
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) message('Copied. Paste into Notes, Files or a message.');
  }

  Future<void> restoreBackup() async {
    final data = await editEntry(context, 'Merge a backup', const [
      EntryField('backup', 'Backup JSON', multiline: true),
    ]);
    if (data == null || store == null || busy) return;
    setState(() => busy = true);
    try {
      List<Record> next;
      if (loadError != null) {
        store!.decode(data['backup'] as String);
        if (!mounted) return;
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace unreadable records?'),
            content: const Text(
              'Copy the preserved data first if you need it. The verified backup will replace the unreadable records.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep original'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore backup'),
              ),
            ],
          ),
        );
        if (yes != true) return;
        next = await store!.replaceUnreadable(data['backup'] as String);
      } else {
        next = await store!.restore(data['backup'] as String);
      }
      if (mounted) {
        setState(() {
          records = next;
          loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        message(
          e is FormatException
              ? e.message
              : 'Invalid backup. Nothing was changed.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget page({
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onAdd,
    required Widget tools,
    required String toolsLabel,
    required List<Widget> children,
    Widget? summary,
  }) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Records and tools',
          onSelected: (value) {
            if (value == 'backup' && store != null) {
              copyText(
                store!.prefs.getString(store!.key) ?? store!.encode(records),
              );
            }
            if (value == 'restore') restoreBackup();
            if (value == 'tools') {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => tools));
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'backup', child: Text('Copy backup')),
            const PopupMenuItem(value: 'restore', child: Text('Merge backup')),
            PopupMenuItem(value: 'tools', child: Text(toolsLabel)),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: store == null && loadError == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                if (loadError != null)
                  Text(
                    loadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ...(summary == null ? <Widget>[] : [summary]),
                if (store != null && loadError == null)
                  FilledButton.icon(
                    onPressed: busy ? null : onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(action),
                  ),
                if (busy) const LinearProgressIndicator(),
                const SizedBox(height: 20),
                ...children,
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => tools)),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(toolsLabel),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Records stay on this device. Copy a backup before uninstalling.',
                ),
              ],
            ),
    ),
  );
  Widget card(String title, List<Widget> children, {String? subtitle}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) Text(subtitle),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget action(
    String label,
    VoidCallback callback, {
    IconData icon = Icons.edit_outlined,
  }) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: OutlinedButton.icon(
      onPressed: busy ? null : callback,
      icon: Icon(icon, size: 20),
      label: Text(label),
    ),
  );
}
