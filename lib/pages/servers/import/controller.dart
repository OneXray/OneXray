import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/servers/import/page.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';
import 'package:permission_handler/permission_handler.dart';

enum ServerImportAction { scan, paste, subscription, file, json }

class ServerImportController extends ChangeNotifier {
  final ServerImportService service;
  final int? subscriptionId;
  final Future<SubscriptionData?> Function(int) _loadSubscription;
  final Future<SubscriptionUpdateResult> Function(int, SubscriptionInput)
  _saveSubscriptionInput;
  final Future<String?> Function(SubscriptionInput, int?) _validateSubscription;
  ServerImportController({
    ServerImportService? service,
    this.subscriptionId,
    Future<SubscriptionData?> Function(int)? loadSubscription,
    Future<SubscriptionUpdateResult> Function(int, SubscriptionInput)?
    saveSubscriptionInput,
    Future<String?> Function(SubscriptionInput, int?)? validateSubscription,
  }) : service = service ?? ServerImportService(),
       _loadSubscription =
           loadSubscription ?? AppDatabase().subscriptionDao.searchRow,
       _saveSubscriptionInput =
           saveSubscriptionInput ?? SubscriptionService().saveSubscriptionInput,
       _validateSubscription =
           validateSubscription ??
           ((input, id) async {
             final result = await SubscriptionValidator.validate(
               input.name,
               input.url,
               excludingId: id,
             );
             return result.item1 ? null : result.item2;
           }) {
    for (final field in [text, name, url, secretKey, publicKey]) {
      field.addListener(_changed);
    }
  }

  final text = TextEditingController();
  final name = TextEditingController();
  final url = TextEditingController();
  final secretKey = TextEditingController();
  final publicKey = TextEditingController();
  bool busy = false;
  bool obscureSecret = true;
  bool loadFailed = false;
  String? error;
  bool _disposed = false;
  bool _closingFlow = false;
  bool _previewOpen = false;
  final _completedSubscriptions = <String, ServerSubscriptionImport>{};
  AgeKeyType? _linkAgeType;
  List<ServerSubscriptionImport> subscriptionImports = const [];
  ServerImportResult? committedResult;
  int get importedSubscriptionCount =>
      subscriptionImports.where((item) => item.result.success).length;
  int get importedSubscriptionNodes => subscriptionImports
      .where((item) => item.result.success)
      .fold(0, (total, item) => total + item.result.count);

  bool get supportsScan => AppPlatform.isMobile;
  bool get editingSubscription => subscriptionId != null;
  bool get incompleteKeys =>
      secretKey.text.trim().isEmpty != publicKey.text.trim().isEmpty;
  bool canSubmit(ServerImportAction action) {
    if (busy || loadFailed) return false;
    if (action == ServerImportAction.subscription) {
      final uri = Uri.tryParse(SubscriptionUrl.normalize(url.text));
      return name.text.trim().isNotEmpty &&
          uri != null &&
          NetClient.isHttpsDownloadUri(uri) &&
          !incompleteKeys;
    }
    return action == ServerImportAction.file ||
        action == ServerImportAction.scan ||
        text.text.trim().isNotEmpty;
  }

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
    if (busy) return;
    // A completed preview must not become an editable, repeatable import again.
    if (_previewOpen && committedResult != null) {
      closeFlow(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  void closeFlow(BuildContext context) {
    if (busy) return;
    _closingFlow = true;
    Navigator.of(context)
        .pop(committedResult ?? (_previewOpen ? null : _subscriptionResult));
  }

  ServerImportResult? get _subscriptionResult => importedSubscriptionCount == 0
      ? null
      : ServerImportResult(
          count: importedSubscriptionNodes,
          subscriptionCount: importedSubscriptionCount,
        );

  Future<void> loadSubscription(BuildContext context) async {
    final id = subscriptionId;
    if (id == null || busy) return;
    busy = true;
    _changed();
    try {
      final row = await _loadSubscription(id);
      if (_disposed) return;
      if (row == null) throw StateError('Subscription no longer exists');
      name.text = row.name;
      url.text = row.url;
      secretKey.text = row.ageSecretKey ?? '';
      publicKey.text = row.agePublicKey ?? '';
    } catch (_) {
      loadFailed = true;
      if (context.mounted) {
        error = AppLocalizations.of(context)!.buttonSaveFailed;
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> open(BuildContext context, ServerImportAction action) async {
    if (busy) return;
    _closingFlow = false;
    error = null;
    committedResult = null;
    _changed();
    ServerImportResult? result;
    if (action == ServerImportAction.file ||
        action == ServerImportAction.scan) {
      String? input;
      busy = true;
      _changed();
      try {
        input = action == ServerImportAction.file
            ? await ServerImportService.pickTextFile()
            : await _scan(context);
        busy = false;
        _changed();
        if (input != null && context.mounted) {
          result = await _importText(context, input);
        }
      } catch (_) {
        if (context.mounted) {
          error = AppLocalizations.of(context)!.prototypeCannotReadContent;
        }
        _changed();
      } finally {
        busy = false;
        _changed();
      }
    } else {
      if (action == ServerImportAction.json && text.text.isEmpty) {
        text.text = '{\n  "outbounds": []\n}';
      }
      result = await showAppDialog<ServerImportResult>(
        context,
        (dialogContext) => ServerImportFormPage(
          controller: this,
          action: action,
          onBack: () => closePage(dialogContext),
          onClose: () => closeFlow(dialogContext),
        ),
      );
    }
    if ((result != null || _closingFlow) && context.mounted) {
      Navigator.of(context)
          .pop(result ?? committedResult ?? _subscriptionResult);
    }
  }

  Future<void> openText(BuildContext context, String input) async {
    _closingFlow = false;
    final result = await _importText(context, input);
    if ((result != null || _closingFlow) && context.mounted) {
      Navigator.of(context)
          .pop(result ?? committedResult ?? _subscriptionResult);
    }
  }

  Future<ServerImportResult?> _importText(
    BuildContext context,
    String input,
  ) async {
    final ServerImportDetection detection;
    try {
      detection = service.detect(input);
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeCannotReadContent;
      }
      _changed();
      return null;
    }
    final link = ServerImportService.singleLink(input);
    committedResult = null;
    if (link is OneXraySubscriptionLink) {
      subscriptionImports = const [];
      name.text = link.name;
      url.text = link.url;
      secretKey.clear();
      publicKey.clear();
      _linkAgeType = link.ageKeyType;
      return showAppDialog<ServerImportResult>(
        context,
        (dialogContext) => ServerImportFormPage(
          controller: this,
          action: ServerImportAction.subscription,
          onBack: () => closePage(dialogContext),
          onClose: () => closeFlow(dialogContext),
        ),
      );
    }
    busy = true;
    error = null;
    subscriptionImports = const [];
    _changed();
    try {
      // Back only reopens the local draft; successful subscriptions are not
      // downloaded and inserted again when Detect is pressed a second time.
      final pending = detection.subscriptions
          .where((link) => !_completedSubscriptions.containsKey(link.url))
          .toList();
      final results = await service.importSubscriptions(pending);
      for (var index = 0; index < results.length; index++) {
        if (results[index].result.success) {
          _completedSubscriptions[pending[index].url] = results[index];
        }
      }
      subscriptionImports = [
        ..._completedSubscriptions.values,
        ...results.where((item) => !item.result.success),
      ];
    } finally {
      busy = false;
      _changed();
    }
    if (!context.mounted) return null;
    ServerImportResult? local;
    if (detection.localText.trim().isNotEmpty) {
      local = await _preview(context, detection.localText);
    }
    if (local == null && importedSubscriptionCount == 0) return null;
    final result = ServerImportResult(
      count: importedSubscriptionNodes + (local?.count ?? 0),
      rawCount: local?.rawCount ?? 0,
      customCount: local?.customCount ?? 0,
      geoDataCount: local?.geoDataCount ?? 0,
      subscriptionCount: importedSubscriptionCount,
      failureCount: local?.failureCount,
      failedGeoData: local?.failedGeoData ?? const [],
    );
    if (detection.localText.trim().isNotEmpty &&
        local == null &&
        !_closingFlow) {
      committedResult = result;
      _changed();
      return null;
    }
    if (detection.localText.trim().isEmpty) {
      if (subscriptionImports.any((item) => !item.result.success)) {
        // Keep failures visible and the original input available for retry.
        // Closing this input still reports subscriptions already imported.
        committedResult = result;
        _changed();
        return null;
      }
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.prototypeUsableNodes(result.count),
        );
      }
    }
    return result;
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
    var pickingImage = false;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (scannerContext) => ServerImportScannerPage(
          onDetect: (capture) {
            final value = capture.barcodes.firstOrNull?.rawValue;
            if (completed || pickingImage || value == null) return;
            completed = true;
            Navigator.of(scannerContext).pop(value);
          },
          onPickImage: () async {
            if (completed || pickingImage) return;
            pickingImage = true;
            final value = await pickQrImage(scannerContext);
            pickingImage = false;
            if (completed || value == null || !scannerContext.mounted) return;
            completed = true;
            Navigator.of(scannerContext).pop(value);
          },
        ),
      ),
    );
  }

  Future<String?> pickQrImage(BuildContext context) async {
    try {
      return await ServerImportService.pickQrImage();
    } catch (_) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.prototypeCannotReadContent,
        );
      }
      return null;
    }
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
    if ((result != null || _closingFlow) && context.mounted) {
      Navigator.of(context)
          .pop(result ?? committedResult ?? _subscriptionResult);
    }
  }

  Future<ServerImportResult?> _preview(
    BuildContext context,
    String input, {
    bool manual = false,
  }) async {
    busy = true;
    error = null;
    committedResult = null;
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
    if (preview == null) return null;
    if (!context.mounted) {
      await preview.dispose();
      return null;
    }
    final ready = preview;
    _previewOpen = true;
    try {
      return await showAppDialog<ServerImportResult>(
        context,
        (dialogContext) => ServerImportPreviewPage(
          controller: this,
          preview: ready,
          onBack: () => closePage(dialogContext),
          onClose: () => closeFlow(dialogContext),
        ),
      );
    } finally {
      _previewOpen = false;
      await ready.dispose();
    }
  }

  Future<void> confirm(
    BuildContext context,
    ServerImportPreview preview,
  ) async {
    if (busy) return;
    if (committedResult != null) {
      Navigator.of(context).pop(committedResult);
      return;
    }
    busy = true;
    error = null;
    _changed();
    try {
      final result = await service.commit(preview);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        if (result.writeFailureCount > 0) {
          committedResult = result;
          return;
        }
        ContextAlert.showToast(
          context,
          result.count > 0
              ? l10n.prototypeUsableNodes(result.count)
              : result.rawCount > 0
              ? l10n.prototypeNameSaved(
                  preview.rows
                      .where((row) => row.type.value == 'raw')
                      .map((row) => row.name.value)
                      .join(', '),
                )
              : result.customCount > 0
              ? l10n.prototypeNameSaved(
                  preview.customRoutes.map((route) => route.name).join(', '),
                )
              : l10n.prototypeGeodataAdded,
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
    if (busy || loadFailed) return;
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
      if (input.hasIncompleteAgeKeyPair) {
        if (!context.mounted) return;
        error = AppLocalizations.of(context)!.prototypeAgeBothKeysRequired;
        return;
      }
      final problem = await _validateSubscription(input, subscriptionId);
      if (problem != null) {
        error = problem;
        return;
      }
      if (subscriptionId != null) {
        final status = await _saveSubscriptionInput(subscriptionId!, input);
        if (!context.mounted) return;
        if (status == SubscriptionUpdateResult.success) {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.prototypeSubscriptionSaved,
          );
          Navigator.of(context).pop(subscriptionId);
        } else {
          error = subscriptionError(AppLocalizations.of(context)!, status);
        }
        return;
      }
      final result = await SubscriptionService().insertSubscription(
        input,
        false,
      );
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (!result.success) {
        error = subscriptionError(l10n, result.status);
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

  static String subscriptionError(
    AppLocalizations l10n,
    SubscriptionUpdateResult status,
  ) => switch (status) {
    SubscriptionUpdateResult.downloadFailed => l10n.subscriptionDownloadFailed,
    SubscriptionUpdateResult.invalidAgeSecretKey =>
      l10n.subscriptionInvalidAgeSecretKey,
    SubscriptionUpdateResult.missingAgeSecretKey =>
      l10n.subscriptionMissingAgeSecretKey,
    SubscriptionUpdateResult.decryptFailed => l10n.subscriptionDecryptFailed,
    SubscriptionUpdateResult.contentTooLarge =>
      l10n.subscriptionDecryptedTooLarge,
    SubscriptionUpdateResult.invalidContent =>
      l10n.prototypeSubscriptionNotAdded,
    _ => l10n.buttonSaveFailed,
  };

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
