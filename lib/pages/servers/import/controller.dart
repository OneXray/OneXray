import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/servers/import/page.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:re_editor/re_editor.dart';

enum ServerImportAction { scan, paste, subscription, file, json }

@immutable
class ServerImportPageState {
  static const _unset = Object();

  ServerImportPageState({
    this.inputText = '',
    this.jsonInput = '',
    this.name = '',
    this.url = '',
    this.secretKey = '',
    this.publicKey = '',
    this.busy = false,
    this.loadingSubscription = false,
    this.openingAction,
    this.generatingAgeKeyType,
    this.obscureSecret = true,
    this.loadFailed = false,
    this.error,
    List<ServerSubscriptionImport> subscriptionImports = const [],
    this.committedResult,
    this.ageExpanded = false,
    this.hasAgeKeys = false,
    this.scannerPickingImage = false,
  }) : subscriptionImports = List.unmodifiable(subscriptionImports);

  final String inputText;
  final String jsonInput;
  final String name;
  final String url;
  final String secretKey;
  final String publicKey;
  final bool busy;
  final bool loadingSubscription;
  final ServerImportAction? openingAction;
  final AgeKeyType? generatingAgeKeyType;
  final bool obscureSecret;
  final bool loadFailed;
  final String? error;
  final List<ServerSubscriptionImport> subscriptionImports;
  final ServerImportResult? committedResult;
  final bool ageExpanded;
  final bool hasAgeKeys;
  final bool scannerPickingImage;

  bool get generatingAgeKey => generatingAgeKeyType != null;
  bool get submitting => busy && !loadingSubscription && openingAction == null;
  bool get canClose => !busy || loadingSubscription || openingAction != null;
  bool get incompleteKeys =>
      secretKey.trim().isEmpty != publicKey.trim().isEmpty;
  int get importedSubscriptionCount =>
      subscriptionImports.where((item) => item.result.success).length;
  int get importedSubscriptionNodes => subscriptionImports
      .where((item) => item.result.success)
      .fold(0, (total, item) => total + item.result.count);

  ServerImportPageState copyWith({
    String? inputText,
    String? jsonInput,
    String? name,
    String? url,
    String? secretKey,
    String? publicKey,
    bool? busy,
    bool? loadingSubscription,
    Object? openingAction = _unset,
    Object? generatingAgeKeyType = _unset,
    bool? obscureSecret,
    bool? loadFailed,
    Object? error = _unset,
    List<ServerSubscriptionImport>? subscriptionImports,
    Object? committedResult = _unset,
    bool? ageExpanded,
    bool? hasAgeKeys,
    bool? scannerPickingImage,
  }) => ServerImportPageState(
    inputText: inputText ?? this.inputText,
    jsonInput: jsonInput ?? this.jsonInput,
    name: name ?? this.name,
    url: url ?? this.url,
    secretKey: secretKey ?? this.secretKey,
    publicKey: publicKey ?? this.publicKey,
    busy: busy ?? this.busy,
    loadingSubscription: loadingSubscription ?? this.loadingSubscription,
    openingAction: identical(openingAction, _unset)
        ? this.openingAction
        : openingAction as ServerImportAction?,
    generatingAgeKeyType: identical(generatingAgeKeyType, _unset)
        ? this.generatingAgeKeyType
        : generatingAgeKeyType as AgeKeyType?,
    obscureSecret: obscureSecret ?? this.obscureSecret,
    loadFailed: loadFailed ?? this.loadFailed,
    error: identical(error, _unset) ? this.error : error as String?,
    subscriptionImports: subscriptionImports ?? this.subscriptionImports,
    committedResult: identical(committedResult, _unset)
        ? this.committedResult
        : committedResult as ServerImportResult?,
    ageExpanded: ageExpanded ?? this.ageExpanded,
    hasAgeKeys: hasAgeKeys ?? this.hasAgeKeys,
    scannerPickingImage: scannerPickingImage ?? this.scannerPickingImage,
  );
}

class ServerImportController extends PageCubit<ServerImportPageState> {
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
           }),
       super(ServerImportPageState()) {
    jsonText.addListener(_changed);
    for (final field in [text, name, url, secretKey, publicKey]) {
      field.addListener(_changed);
    }
  }

  final text = TextEditingController();
  final jsonText = CodeLineEditingController();
  final name = TextEditingController();
  final url = TextEditingController();
  final secretKey = TextEditingController();
  final publicKey = TextEditingController();
  bool _closingFlow = false;
  bool _previewOpen = false;
  final _completedSubscriptions = <String, ServerSubscriptionImport>{};
  AgeKeyType? _linkAgeType;

  bool get supportsScan => AppPlatform.isMobile;
  bool get editingSubscription => subscriptionId != null;
  bool canSubmit(ServerImportAction action) {
    if (state.busy || state.generatingAgeKey || state.loadFailed) return false;
    if (action == ServerImportAction.subscription) {
      final uri = Uri.tryParse(SubscriptionUrl.normalize(state.url));
      return state.name.trim().isNotEmpty &&
          uri != null &&
          NetClient.isHttpsDownloadUri(uri) &&
          !state.incompleteKeys;
    }
    return action == ServerImportAction.file ||
        action == ServerImportAction.scan ||
        (action == ServerImportAction.json ? state.jsonInput : state.inputText)
            .trim()
            .isNotEmpty;
  }

  void _changed() {
    final hasAgeKeys =
        secretKey.text.trim().isNotEmpty || publicKey.text.trim().isNotEmpty;
    emit(
      state.copyWith(
        inputText: text.text,
        jsonInput: jsonText.text,
        name: name.text,
        url: url.text,
        secretKey: secretKey.text,
        publicKey: publicKey.text,
        hasAgeKeys: hasAgeKeys,
        ageExpanded: state.ageExpanded || (hasAgeKeys && !state.hasAgeKeys),
      ),
    );
  }

  void closePage(BuildContext context) {
    if (!state.canClose) return;
    // A completed preview must not become an editable, repeatable import again.
    if (_previewOpen && state.committedResult != null) {
      closeFlow(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  void closeFlow(BuildContext context) {
    if (!state.canClose) return;
    _closingFlow = true;
    Navigator.of(
      context,
    ).pop(state.committedResult ?? (_previewOpen ? null : _subscriptionResult));
  }

  ServerImportResult? get _subscriptionResult =>
      state.importedSubscriptionCount == 0
      ? null
      : ServerImportResult(
          count: state.importedSubscriptionNodes,
          subscriptionCount: state.importedSubscriptionCount,
        );

  Future<void> loadSubscription(BuildContext context) async {
    final id = subscriptionId;
    if (id == null || state.busy) return;
    final fields = [name, url, secretKey, publicKey];
    final initialValues = fields.map((field) => field.text).toList();
    emit(state.copyWith(busy: true, loadingSubscription: true));
    try {
      final row = await _loadSubscription(id);
      if (!isPageActive) return;
      if (row == null) throw StateError('Subscription no longer exists');
      final loadedValues = [
        row.name,
        row.url,
        row.ageSecretKey ?? '',
        row.agePublicKey ?? '',
      ];
      for (var index = 0; index < fields.length; index++) {
        if (fields[index].text == initialValues[index]) {
          fields[index].text = loadedValues[index];
        }
      }
    } catch (_) {
      if (context.mounted) {
        emit(
          state.copyWith(
            loadFailed: true,
            error: AppLocalizations.of(context)!.buttonSaveFailed,
          ),
        );
      }
    } finally {
      emit(state.copyWith(busy: false, loadingSubscription: false));
    }
  }

  Future<void> open(BuildContext context, ServerImportAction action) async {
    if (state.busy) return;
    _closingFlow = false;
    emit(state.copyWith(error: null, committedResult: null));
    ServerImportResult? result;
    if (action == ServerImportAction.file ||
        action == ServerImportAction.scan) {
      String? input;
      emit(state.copyWith(busy: true, openingAction: action));
      try {
        input = action == ServerImportAction.file
            ? await ServerImportService.pickTextFile()
            : await _scan(context);
        emit(state.copyWith(busy: false, openingAction: null));
        if (input != null && isPageActive && context.mounted) {
          result = await _importText(context, input);
        }
      } catch (_) {
        if (context.mounted) {
          emit(
            state.copyWith(
              error: AppLocalizations.of(context)!.prototypeCannotReadContent,
            ),
          );
        }
      } finally {
        emit(state.copyWith(busy: false, openingAction: null));
      }
    } else {
      if (action == ServerImportAction.json && jsonText.text.isEmpty) {
        jsonText.text = '{\n  "outbounds": []\n}';
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
          .pop(result ?? state.committedResult ?? _subscriptionResult);
    }
  }

  Future<void> openText(BuildContext context, String input) async {
    _closingFlow = false;
    final result = await _importText(context, input);
    if ((result != null || _closingFlow) && context.mounted) {
      Navigator.of(context)
          .pop(result ?? state.committedResult ?? _subscriptionResult);
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
        emit(
          state.copyWith(
            error: AppLocalizations.of(context)!.prototypeCannotReadContent,
          ),
        );
      }
      return null;
    }
    final link = ServerImportService.singleLink(input);
    emit(state.copyWith(committedResult: null));
    if (link is OneXraySubscriptionLink) {
      emit(state.copyWith(subscriptionImports: const []));
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
    emit(
      state.copyWith(busy: true, error: null, subscriptionImports: const []),
    );
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
      emit(
        state.copyWith(
          subscriptionImports: [
            ..._completedSubscriptions.values,
            ...results.where((item) => !item.result.success),
          ],
        ),
      );
    } finally {
      emit(state.copyWith(busy: false));
    }
    if (!context.mounted) return null;
    ServerImportResult? local;
    if (detection.localText.trim().isNotEmpty) {
      local = await _preview(context, detection.localText);
    }
    if (local == null && state.importedSubscriptionCount == 0) return null;
    final result = ServerImportResult(
      count: state.importedSubscriptionNodes + (local?.count ?? 0),
      rawCount: local?.rawCount ?? 0,
      customCount: local?.customCount ?? 0,
      geoDataCount: local?.geoDataCount ?? 0,
      subscriptionCount: state.importedSubscriptionCount,
      failureCount: local?.failureCount,
      failedGeoData: local?.failedGeoData ?? const [],
    );
    if (detection.localText.trim().isNotEmpty &&
        local == null &&
        !_closingFlow) {
      emit(state.copyWith(committedResult: result));
      return null;
    }
    if (detection.localText.trim().isEmpty) {
      if (state.subscriptionImports.any((item) => !item.result.success)) {
        // Keep failures visible and the original input available for retry.
        // Closing this input still reports subscriptions already imported.
        emit(state.copyWith(committedResult: result));
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
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (scannerContext) => ServerImportScannerPage(
          controller: this,
          onDetect: (capture) {
            final value = capture.barcodes.firstOrNull?.rawValue;
            if (completed || state.scannerPickingImage || value == null) {
              return;
            }
            completed = true;
            Navigator.of(scannerContext).pop(value);
          },
          onPickImage: () async {
            if (completed || state.scannerPickingImage) return;
            emit(state.copyWith(scannerPickingImage: true));
            try {
              final value = await pickQrImage(scannerContext);
              if (completed || value == null || !scannerContext.mounted) return;
              completed = true;
              Navigator.of(scannerContext).pop(value);
            } finally {
              emit(state.copyWith(scannerPickingImage: false));
            }
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
      if (!isPageActive) return;
      if (input == null) throw const FormatException('Empty clipboard');
      text.text = input;
      emit(state.copyWith(error: null));
    } catch (_) {
      if (context.mounted) {
        emit(
          state.copyWith(
            error: AppLocalizations.of(context)!.prototypeCannotReadContent,
          ),
        );
      }
    }
  }

  Future<void> detect(BuildContext context, ServerImportAction action) async {
    if (state.busy) return;
    final result = action == ServerImportAction.json
        ? await _preview(context, state.jsonInput, manual: true)
        : await _importText(context, state.inputText);
    if ((result != null || _closingFlow) && context.mounted) {
      Navigator.of(context)
          .pop(result ?? state.committedResult ?? _subscriptionResult);
    }
  }

  Future<ServerImportResult?> _preview(
    BuildContext context,
    String input, {
    bool manual = false,
  }) async {
    emit(state.copyWith(busy: true, error: null, committedResult: null));
    ServerImportPreview? preview;
    try {
      preview = await service.preview(input, manual: manual);
    } catch (_) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        emit(
          state.copyWith(
            error: manual
                ? l10n.prototypeNodeJsonHint
                : l10n.prototypeNoSupportedLinks,
          ),
        );
      }
    } finally {
      emit(state.copyWith(busy: false));
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
    if (state.busy) return;
    if (state.committedResult != null) {
      Navigator.of(context).pop(state.committedResult);
      return;
    }
    emit(state.copyWith(busy: true, error: null));
    try {
      final result = await service.commit(preview);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        if (result.writeFailureCount > 0) {
          emit(state.copyWith(committedResult: result));
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
        emit(
          state.copyWith(error: AppLocalizations.of(context)!.buttonAddFailed),
        );
      }
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> subscribe(BuildContext context) async {
    if (state.busy || state.generatingAgeKey || state.loadFailed) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      if (_linkAgeType != null &&
          secretKey.text.trim().isEmpty &&
          publicKey.text.trim().isEmpty) {
        final pair = await AppHostApi().generateAgeKeyPair(
          keyType: _linkAgeType!,
        );
        if (!isPageActive) return;
        secretKey.text = pair.secretKey ?? '';
        publicKey.text = pair.publicKey ?? '';
        if (secretKey.text.isEmpty || publicKey.text.isEmpty) {
          throw StateError('Missing Age keys');
        }
      }
      final input = SubscriptionInput(
        name: state.name.trim(),
        url: SubscriptionUrl.normalize(state.url),
        ageSecretKey: state.secretKey,
        agePublicKey: state.publicKey,
      );
      if (input.hasIncompleteAgeKeyPair) {
        if (!context.mounted) return;
        emit(
          state.copyWith(
            error: AppLocalizations.of(context)!.prototypeAgeBothKeysRequired,
          ),
        );
        return;
      }
      final problem = await _validateSubscription(input, subscriptionId);
      if (!isPageActive || !context.mounted) return;
      if (problem != null) {
        emit(state.copyWith(error: problem));
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
          emit(
            state.copyWith(
              error: subscriptionError(AppLocalizations.of(context)!, status),
            ),
          );
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
        emit(state.copyWith(error: subscriptionError(l10n, result.status)));
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
        emit(
          state.copyWith(error: AppLocalizations.of(context)!.buttonAddFailed),
        );
      }
    } finally {
      emit(state.copyWith(busy: false));
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

  void toggleSecret() {
    emit(state.copyWith(obscureSecret: !state.obscureSecret));
  }

  void toggleAgeExpanded() {
    emit(state.copyWith(ageExpanded: !state.ageExpanded));
  }

  void clearKeys() {
    if (state.busy || state.generatingAgeKey) return;
    secretKey.clear();
    publicKey.clear();
  }

  Future<void> generateKeys(BuildContext context, AgeKeyType type) async {
    if (state.busy || state.generatingAgeKey || !isPageActive) return;
    final l10n = AppLocalizations.of(context)!;
    emit(state.copyWith(generatingAgeKeyType: type, error: null));
    try {
      if (secretKey.text.isNotEmpty || publicKey.text.isNotEmpty) {
        if (!await ContextAlert.showConfirmDialog(
              context,
              title: l10n.prototypeReplaceAgeKeys,
              content: l10n.subscriptionReplaceAgeKeyMessage,
              confirmLabel: l10n.subscriptionGenerateAgeKey,
            ) ||
            !isPageActive ||
            !context.mounted) {
          return;
        }
      }
      final pair = await AppHostApi().generateAgeKeyPair(keyType: type);
      if (isPageActive) {
        secretKey.text = pair.secretKey ?? '';
        publicKey.text = pair.publicKey ?? '';
      }
    } catch (_) {
      emit(state.copyWith(error: l10n.subscriptionGenerateAgeKeyFailed));
    } finally {
      emit(state.copyWith(generatingAgeKeyType: null));
    }
  }

  @override
  void disposePageResources() {
    jsonText.removeListener(_changed);
    jsonText.dispose();
    for (final controller in [text, name, url, secretKey, publicKey]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
  }
}
