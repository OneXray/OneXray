import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/connect/raw_editor/page.dart';
import 'package:onexray/pages/servers/import/page.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';
import 'package:permission_handler/permission_handler.dart';

enum ServerImportAction { scan, paste, subscription, file, json }

class ServerImportController extends ChangeNotifier {
  final ServerImportService service;
  ServerImportController({ServerImportService? service})
    : service = service ?? ServerImportService() {
    text.addListener(_changed);
  }

  final text = TextEditingController();
  final name = TextEditingController();
  final url = TextEditingController();
  final secretKey = TextEditingController();
  final publicKey = TextEditingController();
  bool busy = false;
  bool obscureSecret = true;
  String? error;
  bool _disposed = false;
  AgeKeyType? _linkAgeType;

  bool get supportsScan => AppPlatform.isMobile;
  bool get incompleteKeys =>
      secretKey.text.trim().isEmpty != publicKey.text.trim().isEmpty;
  int get lineCount => '\n'.allMatches(text.text).length + 1;
  bool get validJson {
    try {
      return jsonDecode(text.text) is Map;
    } catch (_) {
      return false;
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void closePage(BuildContext context) {
    if (!busy) Navigator.of(context).pop();
  }

  Future<void> open(BuildContext context, ServerImportAction action) async {
    if (busy) return;
    error = null;
    _changed();
    ServerImportResult? result;
    if (action == ServerImportAction.file ||
        action == ServerImportAction.scan) {
      String? input;
      try {
        input = action == ServerImportAction.file
            ? await ServerImportService.pickTextFile()
            : await _scan(context);
        if (input != null && context.mounted) {
          result = await _importText(context, input);
        }
      } catch (_) {
        if (context.mounted) {
          error = AppLocalizations.of(context)!.prototypeCannotReadContent;
        }
        _changed();
      }
    } else {
      if (action == ServerImportAction.paste && text.text.isEmpty) {
        await readClipboard(context);
        if (!context.mounted) return;
      }
      if (action == ServerImportAction.json && text.text.isEmpty) {
        text.text = '{\n  "outbounds": []\n}';
      }
      result = await Navigator.of(context).push<ServerImportResult>(
        MaterialPageRoute(
          builder: (_) =>
              ServerImportFormPage(controller: this, action: action),
        ),
      );
    }
    if (result != null && context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> openText(BuildContext context, String input) async {
    final result = await _importText(context, input);
    if (result != null && context.mounted) Navigator.of(context).pop(result);
  }

  Future<ServerImportResult?> _importText(
    BuildContext context,
    String input,
  ) async {
    final link = ServerImportService.singleLink(input);
    if (link is OneXraySubscriptionLink) {
      name.text = link.name;
      url.text = link.url;
      _linkAgeType = link.ageKeyType;
      return Navigator.of(context).push<ServerImportResult>(
        MaterialPageRoute(
          builder: (_) => ServerImportFormPage(
            controller: this,
            action: ServerImportAction.subscription,
          ),
        ),
      );
    }
    if (link is OneXrayConfigLink && link.type == OneXrayConfigLinkType.raw) {
      final id = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) =>
              RawEditorPage(initialText: link.xrayJson, initialName: link.name),
        ),
      );
      return id == null ? null : const ServerImportResult(count: 1);
    }
    return _preview(context, input);
  }

  Future<String?> _scan(BuildContext context) async {
    if (!supportsScan) return null;
    final permission = await Permission.camera.request();
    if (!context.mounted) return null;
    if (!permission.isGranted) {
      await ContextAlert.showPermissionDialog(context);
      return null;
    }
    var completed = false;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (scannerContext) => ServerImportScannerPage(
          onDetect: (capture) {
            final value = capture.barcodes.firstOrNull?.rawValue;
            if (completed || value == null) return;
            completed = true;
            Navigator.of(scannerContext).pop(value);
          },
        ),
      ),
    );
  }

  Future<void> readClipboard(BuildContext context) async {
    try {
      final input = await ServerImportService.readClipboard();
      if (input == null) throw const FormatException('Empty clipboard');
      text.text = input;
      error = null;
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeCannotReadContent;
      }
    }
    _changed();
  }

  Future<void> detect(BuildContext context, ServerImportAction action) async {
    if (busy) return;
    final result = action == ServerImportAction.json
        ? await _preview(context, text.text, manual: true)
        : await _importText(context, text.text);
    if (result != null && context.mounted) Navigator.of(context).pop(result);
  }

  Future<ServerImportResult?> _preview(
    BuildContext context,
    String input, {
    bool manual = false,
  }) async {
    busy = true;
    error = null;
    _changed();
    ServerImportPreview? preview;
    try {
      preview = await service.preview(input, manual: manual);
    } catch (_) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        error = manual
            ? l10n.prototypeNodeJsonHint
            : l10n.prototypeNoSupportedLinks;
      }
    } finally {
      busy = false;
      _changed();
    }
    if (preview == null || !context.mounted) return null;
    final ready = preview;
    return Navigator.of(context).push<ServerImportResult>(
      MaterialPageRoute(
        builder: (_) =>
            ServerImportPreviewPage(controller: this, preview: ready),
      ),
    );
  }

  Future<void> confirm(
    BuildContext context,
    ServerImportPreview preview,
  ) async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    try {
      final result = await service.commit(preview);
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.prototypeUsableNodes(result.count),
        );
        Navigator.of(context).pop(result);
      }
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.buttonAddFailed;
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> subscribe(BuildContext context) async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    try {
      if (_linkAgeType != null &&
          secretKey.text.trim().isEmpty &&
          publicKey.text.trim().isEmpty) {
        final pair = await AppHostApi().generateAgeKeyPair(
          keyType: _linkAgeType!,
        );
        if (_disposed) return;
        secretKey.text = pair.secretKey ?? '';
        publicKey.text = pair.publicKey ?? '';
        if (secretKey.text.isEmpty || publicKey.text.isEmpty) {
          throw StateError('Missing Age keys');
        }
      }
      final input = SubscriptionInput(
        name: name.text.trim(),
        url: SubscriptionUrl.normalize(url.text),
        ageSecretKey: secretKey.text,
        agePublicKey: publicKey.text,
      );
      final checked = await SubscriptionValidator.validate(
        input.name,
        input.url,
      );
      if (!checked.item1) {
        error = checked.item2;
        return;
      }
      final result = await SubscriptionService().insertSubscription(
        input,
        false,
      );
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (!result.success) {
        error = switch (result.status) {
          SubscriptionUpdateResult.downloadFailed =>
            l10n.subscriptionDownloadFailed,
          SubscriptionUpdateResult.invalidAgeSecretKey =>
            l10n.subscriptionInvalidAgeSecretKey,
          SubscriptionUpdateResult.missingAgeSecretKey =>
            l10n.subscriptionMissingAgeSecretKey,
          SubscriptionUpdateResult.decryptFailed =>
            l10n.subscriptionDecryptFailed,
          SubscriptionUpdateResult.contentTooLarge =>
            l10n.subscriptionDecryptedTooLarge,
          SubscriptionUpdateResult.invalidContent =>
            l10n.prototypeSubscriptionNotAdded,
          _ => l10n.buttonAddFailed,
        };
        return;
      }
      ContextAlert.showToast(
        context,
        result.parseFailureCount == null
            ? l10n.prototypeUsableNodes(result.count)
            : l10n.prototypeSubscriptionImportResult(
                input.name,
                result.count,
                result.parseFailureCount!,
              ),
      );
      Navigator.of(context).pop(
        ServerImportResult(
          count: result.count,
          subscriptionId: result.subId,
          failureCount: result.parseFailureCount,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.buttonAddFailed;
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  void ageChanged(String _) => _changed();
  void toggleSecret() {
    obscureSecret = !obscureSecret;
    _changed();
  }

  void clearKeys() {
    secretKey.clear();
    publicKey.clear();
    _changed();
  }

  Future<void> generateKeys(BuildContext context, AgeKeyType type) async {
    if (busy) return;
    final l10n = AppLocalizations.of(context)!;
    if (secretKey.text.isNotEmpty || publicKey.text.isNotEmpty) {
      if (!await ContextAlert.showConfirmDialog(
            context,
            title: l10n.prototypeReplaceAgeKeys,
            content: l10n.subscriptionReplaceAgeKeyMessage,
            confirmLabel: l10n.subscriptionGenerateAgeKey,
          ) ||
          !context.mounted) {
        return;
      }
    }
    busy = true;
    error = null;
    _changed();
    try {
      final pair = await AppHostApi().generateAgeKeyPair(keyType: type);
      if (!_disposed) {
        secretKey.text = pair.secretKey ?? '';
        publicKey.text = pair.publicKey ?? '';
      }
    } catch (_) {
      error = l10n.subscriptionGenerateAgeKeyFailed;
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final controller in [text, name, url, secretKey, publicKey]) {
      controller.dispose();
    }
    super.dispose();
  }
}
