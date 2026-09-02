import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/share/configuration_transfer.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';

class ConfigurationTransferController extends ChangeNotifier {
  final ConfigurationKind kind;
  final String Function() readText;
  final String Function() readName;
  final void Function(ConfigurationImportDraft) onImport;
  final ConfigurationTransferService service;
  ConfigurationImportDraft? _draft;
  bool busy = false;
  bool _disposed = false;
  String? notice;

  ConfigurationTransferController({
    required this.kind,
    required this.readText,
    required this.readName,
    required this.onImport,
    ConfigurationTransferService? service,
  }) : service = service ?? ConfigurationTransferService();

  GeoDataImportDraft? get pending => _draft?.geodata;

  Future<void> import(BuildContext context, {required bool clipboard}) async {
    if (busy) return;
    final l10n = AppLocalizations.of(context)!;
    busy = true;
    notice = null;
    _notify();
    ConfigurationImportDraft? next;
    try {
      final input = clipboard
          ? await ServerImportService.readClipboard()
          : await ServerImportService.pickTextFile(jsonOnly: true);
      if (input == null || !context.mounted || _disposed) return;
      // Parse before asking to replace anything, and download only after consent.
      ConfigurationTransferService.read(input, kind);
      if (readText().trim().isNotEmpty &&
          !await ContextAlert.showConfirmDialog(
            context,
            title: kind == ConfigurationKind.raw
                ? l10n.prototypeReplaceEditorJson
                : l10n.prototypeReplaceCustomRoute,
            content: kind == ConfigurationKind.raw
                ? l10n.prototypeJsonImportedIntoEditor
                : l10n.prototypeCustomImportedIntoEditor,
            confirmLabel: l10n.prototypeImportFile,
          )) {
        return;
      }
      if (!context.mounted || _disposed) return;
      next = await service.import(input, kind);
      if (!context.mounted || _disposed) return;
      onImport(next);
      final previous = _draft;
      _draft = next;
      next = null;
      await previous?.dispose();
      notice = kind == ConfigurationKind.raw
          ? l10n.prototypeJsonImportedIntoEditor
          : l10n.prototypeCustomImportedIntoEditor;
    } catch (_) {
      notice = kind == ConfigurationKind.raw
          ? l10n.prototypeCannotReadContent
          : l10n.prototypeCannotReadCustomRoute;
    } finally {
      await next?.dispose();
      busy = false;
      _notify();
    }
  }

  Future<void> export(BuildContext context, {required bool share}) async {
    if (busy) return;
    final l10n = AppLocalizations.of(context)!;
    if (!await ContextAlert.showConfirmDialog(
          context,
          title: share ? l10n.prototypeShare : l10n.prototypeExportJson,
          content: kind == ConfigurationKind.raw
              ? l10n.prototypeRawJsonShareWarning
              : l10n.prototypeCustomShareWarning,
          confirmLabel: share ? l10n.prototypeShare : l10n.prototypeExportJson,
        ) ||
        !context.mounted ||
        _disposed) {
      return;
    }
    busy = true;
    notice = null;
    _notify();
    try {
      final name = readName();
      final text = readText();
      if (share) {
        final links = await service.shareLinks(
          kind: kind,
          name: name,
          text: text,
          pending: pending,
        );
        if (!context.mounted || _disposed) return;
        if (AppPlatform.isLinux) {
          await Clipboard.setData(ClipboardData(text: links));
          notice = l10n.prototypeConfigurationLinksCopied;
        } else {
          final box = context.findRenderObject() as RenderBox?;
          final result = await SharePlus.instance.share(
            ShareParams(
              title: name,
              text: links,
              sharePositionOrigin: box == null
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size,
            ),
          );
          if (result.status == ShareResultStatus.unavailable) {
            await Clipboard.setData(ClipboardData(text: links));
            notice = l10n.prototypeConfigurationLinksCopied;
          } else if (result.status == ShareResultStatus.success) {
            notice = l10n.prototypeShareSheetOpened;
          }
        }
      } else {
        final json = await service.exportJson(
          kind: kind,
          name: name,
          text: text,
          pending: pending,
        );
        final basename = name.trim().replaceAll(
          RegExp(r'[\\/:*?"<>|\x00-\x1f]'),
          '_',
        );
        if (await FileTool.saveData(
          Uint8List.fromList(utf8.encode(json)),
          '${basename.isEmpty ? 'xray' : basename}.json',
          'json',
        )) {
          notice = kind == ConfigurationKind.raw
              ? l10n.prototypeOriginalJsonExported
              : l10n.prototypeCustomJsonExported;
        }
      }
    } catch (_) {
      notice = l10n.prototypeCannotShareConfiguration;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_draft?.dispose());
    super.dispose();
  }
}

class ConfigurationTransferTools extends StatelessWidget {
  final ConfigurationTransferController controller;
  final bool disabled;
  final List<Widget> children;
  const ConfigurationTransferTools({
    super.key,
    required this.controller,
    this.disabled = false,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final busy = disabled || controller.busy;
      final empty = controller.readText().trim().isEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => controller.import(context, clipboard: false),
                icon: const Icon(LucideIcons.fileInput, size: 16),
                label: Text(l10n.prototypeImportFile),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => controller.import(context, clipboard: true),
                icon: const Icon(LucideIcons.clipboardPaste, size: 16),
                label: Text(l10n.prototypeReadClipboard),
              ),
              OutlinedButton.icon(
                onPressed: busy || empty
                    ? null
                    : () => controller.export(context, share: false),
                icon: const Icon(LucideIcons.fileOutput, size: 16),
                label: Text(l10n.prototypeExportJson),
              ),
              OutlinedButton.icon(
                onPressed: busy || empty
                    ? null
                    : () => controller.export(context, share: true),
                icon: const Icon(LucideIcons.share2, size: 16),
                label: Text(l10n.prototypeShare),
              ),
              ...children,
            ],
          ),
          if (controller.notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  controller.notice!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      );
    },
  );
}
