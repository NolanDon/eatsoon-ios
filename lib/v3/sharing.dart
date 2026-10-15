import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../niche/ai_client.dart' show CompanionException;
import 'brand.dart';
import 'model.dart';
import 'photo_flow.dart';
import 'transfer.dart';
import 'widgets.dart';

Future<void> showSharing(
  BuildContext context,
  V3Store store,
  String directory, {
  required Future<void> Function(bool) onImported,
  int initialTab = 0,
}) async {
  final preferences = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SharingScreen(
        client: TransferClient(store, directory, preferences),
        onImported: onImported,
        initialTab: initialTab,
      ),
    ),
  );
}

Widget _shareTabLabel(String text, bool selected) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (selected) const Icon(Icons.check, size: 14),
    if (selected) const SizedBox(width: 4),
    Flexible(
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
);

class SharingScreen extends StatefulWidget {
  final TransferClient client;
  final Future<void> Function(bool) onImported;
  final int initialTab;
  const SharingScreen({
    super.key,
    required this.client,
    required this.onImported,
    this.initialTab = 0,
  });
  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  final selected = <String>{};
  final code = TextEditingController();
  int tab = 0;
  bool outfits = false, busy = false;
  String progress = '';
  TransferClient get client => widget.client;
  bool get hasCompleteCode {
    try {
      normalizeShareCode(code.text);
      return true;
    } on FormatException {
      return false;
    }
  }

  String get plural => outfits
      ? 'outfits'
      : switch (appKind) {
          'plant' => 'plants',
          'fridge' => 'food items',
          'meal' => 'recipes',
          'drawing' => 'comics',
          'clothing' => 'clothing items',
          'goal' => 'goals',
          'knitting' => 'patterns',
          'wrapping' => 'wrap plans',
          'mending' => 'repair projects',
          _ => 'service records',
        };
  List<Item> get records => outfits ? client.store.outfits : client.store.items;
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void updateProgress(String text) {
    if (mounted) setState(() => progress = text);
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
    } catch (error) {
      if (mounted) {
        notice(
          context,
          error is FormatException
              ? error.message.toString()
              : error is CompanionException
              ? error.message
              : 'Could not finish sharing. Your saved records are safe. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> createShare() async {
    final chosen = records.where((v) => selected.contains(v['id'])).toList();
    if (chosen.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (sheet) => AlertDialog(
        title: const Text('Create a one-use share?'),
        content: const Text(
          'Selected photos and details are stored temporarily on our server. This one-use code expires in 24 hours; anyone with it can claim it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sheet, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(sheet, true),
            child: const Text('Create code'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await run(() async {
      final outfitItems = outfits ? chosen : <Item>[];
      final ids = outfitItems
          .expand((v) => (v['ids'] as List).cast<String>())
          .toSet();
      final items = outfits
          ? client.store.items.where((v) => ids.contains(v['id'])).toList()
          : chosen;
      final receipt = await client.create(
        items,
        outfitItems,
        progress: updateProgress,
      );
      if (mounted) await showReceipt(receipt);
    });
  }

  Future<void> showReceipt(Item receipt) async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ShareReceiptScreen(client: client, initial: receipt),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> importCode() async {
    if (!hasCompleteCode) return;
    await run(() async {
      final result = await client.redeem(code.text, progress: updateProgress);
      if (!mounted) return;
      notice(
        context,
        result.count == 0
            ? 'This collection is already imported.'
            : 'Imported ${result.count} ${pluralForKind()}.',
      );
      await widget.onImported(result.reminders);
      if (mounted) Navigator.pop(context);
    });
  }

  String pluralForKind() => switch (appKind) {
    'plant' => 'plants',
    'fridge' => 'food items',
    'meal' => 'recipes',
    'clothing' => 'clothing items',
    'drawing' => 'comics',
    _ => 'records',
  };
  Future<void> scanCode() async {
    await run(() async {
      final photo = await vision.invokeMapMethod<String, dynamic>('capture', {
        'kind': 'qr',
      });
      if (photo == null) return;
      try {
        final value = await vision.invokeMethod<String>('readTransferQr', {
          'file': photo['file'],
        });
        need(value != null, 'No share QR found. Keep the whole code in frame.');
        code.text = formatShareCode(normalizeShareCode(value!));
      } finally {
        await vision.invokeMethod('removePhoto', {'file': photo['file']});
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          MainTitle(
            'Share',
            onBack: busy ? null : () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: _shareTabLabel('Send', tab == 0),
                ),
                ButtonSegment(
                  value: 1,
                  label: _shareTabLabel('Receive', tab == 1),
                ),
                ButtonSegment(
                  value: 2,
                  label: _shareTabLabel('My codes', tab == 2),
                ),
              ],
              style: ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
              selected: {tab},
              onSelectionChanged: busy
                  ? null
                  : (v) => setState(() => tab = v.first),
            ),
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(progress, semanticsLabel: progress),
                ],
              ),
            ),
          Expanded(
            child: tab == 0
                ? sendList()
                : tab == 1
                ? receiveView()
                : history(),
          ),
          if (tab == 0)
            Padding(
              padding: const EdgeInsets.all(24),
              child: MainAction(
                'Share ${selected.length} $plural',
                busy || selected.isEmpty ? null : createShare,
                icon: Icons.ios_share_outlined,
              ),
            ),
        ],
      ),
    ),
  );
  Widget sendList() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      if (appKind == 'clothing') ...[
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Clothes')),
            ButtonSegment(value: true, label: Text('Outfits')),
          ],
          selected: {outfits},
          onSelectionChanged: busy
              ? null
              : (v) => setState(() {
                  outfits = v.first;
                  selected.clear();
                }),
        ),
        const SizedBox(height: 20),
      ],
      Row(
        children: [
          Expanded(
            child: Text(
              'Choose $plural',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            onPressed: busy || records.isEmpty
                ? null
                : () => setState(() {
                    if (selected.length == records.length) {
                      selected.clear();
                    } else {
                      selected.addAll(records.map((v) => v['id'] as String));
                    }
                  }),
            child: Text(
              selected.length == records.length && records.isNotEmpty
                  ? 'Clear'
                  : 'Share all ${records.length}',
            ),
          ),
        ],
      ),
      if (records.isEmpty) Text('No saved $plural yet.'),
      for (var i = 0; i < records.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(18),
            child: CheckboxListTile(
              value: selected.contains(records[i]['id']),
              onChanged: busy
                  ? null
                  : (checked) => setState(() {
                      if (checked == true) {
                        selected.add(records[i]['id'] as String);
                      } else {
                        selected.remove(records[i]['id']);
                      }
                    }),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              secondary: outfits
                  ? const Icon(Icons.checkroom)
                  : SizedBox(
                      width: 52,
                      height: 52,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Photo(
                          (records[i]['cutout'] ?? records[i]['photo'])
                              as String?,
                          client.directory,
                          width: 52,
                          height: 52,
                        ),
                      ),
                    ),
              title: Text(
                outfits ? 'Outfit ${i + 1}' : records[i]['name'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: outfits
                  ? Text(
                      '${(records[i]['ids'] as List).length} pieces included',
                    )
                  : null,
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        ),
    ],
  );
  Widget receiveView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Bring a shared collection here',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Enter the sender’s code or scan their QR. Photos, saved details and reminder dates come with it.',
      ),
      const SizedBox(height: 24),
      TextField(
        controller: code,
        enabled: !busy,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX-XXXX'),
        maxLength: 200,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy ? null : scanCode,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan QR code'),
      ),
      const SizedBox(height: 20),
      MainAction(
        'Import collection',
        busy || !hasCompleteCode ? null : importCode,
        icon: Icons.download_outlined,
      ),
      const SizedBox(height: 16),
      const Text(
        'Only accept codes from someone you trust. Your current collection stays saved.',
      ),
    ],
  );
  Widget history() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Your one-use codes', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      if (client.receipts.isEmpty)
        const Text('Create a share to see its status and expiry here.'),
      for (final receipt in client.receipts)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: Colors.white.withValues(alpha: .6),
            title: Text(formatShareCode(receipt['code'] as String)),
            subtitle: Text(
              '${receipt['count']} ${receipt['entity'] ?? 'items'} · ${receipt['state']}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => showReceipt(receipt),
          ),
        ),
    ],
  );
}

class ShareReceiptScreen extends StatefulWidget {
  final TransferClient client;
  final Item initial;
  const ShareReceiptScreen({
    super.key,
    required this.client,
    required this.initial,
  });
  @override
  State<ShareReceiptScreen> createState() => _ShareReceiptScreenState();
}

class _ShareReceiptScreenState extends State<ShareReceiptScreen> {
  late Item receipt;
  Uint8List? qr;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    receipt = {...widget.initial};
    refresh();
    loadQr();
  }

  Future<void> loadQr() async {
    try {
      final encoded = await vision.invokeMethod<String>('transferQr', {
        'text': transferLink(receipt['code'] as String),
      });
      if (mounted && encoded != null) {
        setState(() => qr = base64Decode(encoded));
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final updated = await widget.client.status(receipt);
      if (mounted) setState(() => receipt = updated);
    } catch (_) {
      if (mounted) {
        notice(context, 'Could not refresh status. Try again when connected.');
      }
    }
  }

  bool get usable =>
      receipt['state'] == 'ready' &&
      (receipt['expires'] as num) > DateTime.now().millisecondsSinceEpoch;
  String get state => switch (receipt['state']) {
    'claimed' || 'delivered' => 'Claimed',
    'ready' => usable ? 'Ready to claim' : 'Expired',
    'revoked' => 'Revoked',
    'uploading' => 'Upload incomplete',
    'verifying' => 'Checking upload',
    _ => 'Expired',
  };
  Future<void> shareLink() async {
    await vision.invokeMethod('shareTransfer', {
      'text':
          'Import my $appName collection. One-use code: ${formatShareCode(receipt['code'] as String)}\n${transferLink(receipt['code'] as String)}\nGet $appName and enter this code in Share > Receive. Expires ${expiryText()}.',
      'qr': qr == null ? null : base64Encode(qr!),
    });
  }

  String expiryText() {
    final at = DateTime.fromMillisecondsSinceEpoch(
      (receipt['expires'] as num).toInt(),
    ).toLocal();
    return '${day(at)} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }

  Future<void> reshare() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (sheet) => AlertDialog(
        title: const Text('Create another code?'),
        content: const Text(
          'This uploads the same selected records again. The new one-use code expires in 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sheet, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(sheet, true),
            child: const Text('Create code'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final items = widget.client.store.items
          .where((v) => (receipt['itemIds'] as List).contains(v['id']))
          .toList();
      final outfits = widget.client.store.outfits
          .where((v) => (receipt['outfitIds'] as List).contains(v['id']))
          .toList();
      need(
        items.length == (receipt['itemIds'] as List).length &&
            outfits.length == (receipt['outfitIds'] as List).length,
        'Some shared records were removed. Choose a new selection from Share.',
      );
      if (usable || ['uploading', 'verifying'].contains(receipt['state'])) {
        await widget.client.revoke(receipt);
      }
      final fresh = await widget.client.create(
        items,
        outfits,
        progress: (_) {},
      );
      if (mounted) {
        setState(() {
          receipt = fresh;
          qr = null;
        });
        await loadQr();
      }
    } catch (error) {
      if (mounted) {
        notice(
          context,
          error is FormatException
              ? error.message.toString()
              : error is CompanionException
              ? error.message
              : 'Could not create a fresh code. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          MainTitle(
            'Share code',
            onBack: busy ? null : () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Chip(label: Text(state))),
                const SizedBox(height: 20),
                if (qr != null && usable)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(qr!, width: 230, height: 230),
                    ),
                  ),
                const SizedBox(height: 20),
                SelectableText(
                  formatShareCode(receipt['code'] as String),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('Expires ${expiryText()}', textAlign: TextAlign.center),
                if (receipt['claimedAt'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Claimed ${day(DateTime.fromMillisecondsSinceEpoch((receipt['claimedAt'] as num).toInt()).toLocal())}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                MainAction(
                  'Share code and app link',
                  busy || !usable ? null : shareLink,
                  icon: Icons.ios_share_outlined,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : reshare,
                  child: const Text('Create a fresh code'),
                ),
                TextButton(
                  onPressed: busy ? null : refresh,
                  child: const Text('Refresh status'),
                ),
                if (usable)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await widget.client.revoke(receipt);
                            await refresh();
                          },
                    child: const Text('Revoke code'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'The code works once. A fresh code replaces your current unclaimed code.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
