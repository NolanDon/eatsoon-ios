import 'dart:io';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'mascot.dart';

class MainTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const MainTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 14, 16, 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.headlineLarge),
        ),
        ...(trailing == null ? <Widget>[] : [trailing!]),
      ],
    ),
  );
}

class MainAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  const MainAction(this.label, this.onTap, {super.key, this.icon = Icons.add});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 62),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 22),
      ),
      icon: Icon(icon),
      iconAlignment:
          icon == Icons.arrow_forward ||
              icon == Icons.arrow_right_alt ||
              icon == Icons.east
          ? IconAlignment.end
          : IconAlignment.start,
      label: Text(label),
    ),
  );
}

class Photo extends StatelessWidget {
  final String? file;
  final String directory;
  final double? height, width;
  final BoxFit fit;
  const Photo(
    this.file,
    this.directory, {
    super.key,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });
  @override
  Widget build(BuildContext context) {
    if (file == null || directory.isEmpty) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: Icon(
            Icons.photo_outlined,
            size: 48,
            color: ink.withValues(alpha: .35),
          ),
        ),
      );
    }
    return Image.file(
      File('$directory/$file'),
      height: height,
      width: width,
      fit: fit,
      cacheWidth: 800,
      errorBuilder: (_, e, s) => SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 36),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String title, description;
  final IconData icon;
  const EmptyView(this.title, this.description, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Mascot(pose: 'rest', height: 100),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Continue',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
void notice(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
