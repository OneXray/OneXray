import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/advanced/local_api/service.dart';
import 'package:onexray/service/advanced/local_api/settings.dart';
import 'package:onexray/service/shared/failure.dart';

typedef ConfigureLocalApi = Future<LocalApiSettings> Function({
  required bool enabled,
  required int port,
});

class LocalApiPageState {
  final LocalApiSettings? saved;
  final bool enabled;
  final bool loading;
  final bool saving;
  final bool resetting;
  final bool copying;
  final bool listening;
  final String? runtimeError;
  final String? error;

  const LocalApiPageState({
    this.saved,
    this.enabled = false,
    this.loading = true,
    this.saving = false,
    this.resetting = false,
    this.copying = false,
    this.listening = false,
    this.runtimeError,
    this.error,
  });

  bool get loaded => saved != null;
  bool get busy => loading || saving || resetting || copying;

  LocalApiPageState copyWith({
    LocalApiSettings? saved,
    bool? enabled,
    bool? loading,
    bool? saving,
    bool? resetting,
    bool? copying,
    bool? listening,
    String? runtimeError,
    String? error,
  }) => LocalApiPageState(
    saved: saved ?? this.saved,
    enabled: enabled ?? this.enabled,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    resetting: resetting ?? this.resetting,
    copying: copying ?? this.copying,
    listening: listening ?? this.listening,
    runtimeError: runtimeError,
    error: error,
  );
}

class LocalApiController extends PageCubit<LocalApiPageState> {
  LocalApiController({
    Future<LocalApiSettings> Function()? loadSettings,
    ConfigureLocalApi? configure,
    Future<LocalApiSettings> Function()? resetToken,
    bool Function()? listening,
    String? Function()? lastError,
    Future<void> Function(String)? copyToken,
  }) : _loadSettings = loadSettings ?? LocalApiService.instance.load,
       _configure = configure ?? LocalApiService.instance.configure,
       _resetToken = resetToken ?? LocalApiService.instance.resetToken,
       _listening = listening ?? (() => LocalApiService.instance.listening),
       _lastError = lastError ?? (() => LocalApiService.instance.lastError),
       _copyToken = copyToken ?? _writeClipboard,
       super(const LocalApiPageState()) {
    load();
  }

  final Future<LocalApiSettings> Function() _loadSettings;
  final ConfigureLocalApi _configure;
  final Future<LocalApiSettings> Function() _resetToken;
  final bool Function() _listening;
  final String? Function() _lastError;
  final Future<void> Function(String) _copyToken;
  final portController = TextEditingController();

  static Future<void> _writeClipboard(String value) =>
      Clipboard.setData(ClipboardData(text: value));

  String? _safeError(Object? error, {String? token}) {
    if (error == null) return null;
    var text = failureDetails(error);
    for (final secret in [state.saved?.token, token]) {
      if (secret != null && secret.isNotEmpty) {
        text = text.replaceAll(secret, '[redacted]');
      }
    }
    return text;
  }

  Future<void> load() async {
    if (state.saving || state.resetting || state.copying) return;
    emit(state.copyWith(loading: true, runtimeError: state.runtimeError));
    try {
      final value = await _loadSettings();
      if (!isPageActive) return;
      portController.text = '${value.port}';
      emit(
        LocalApiPageState(
          saved: value,
          enabled: value.enabled,
          loading: false,
          listening: _listening(),
          runtimeError: _safeError(_lastError(), token: value.token),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loading: false,
          listening: _listening(),
          runtimeError: _safeError(_lastError()),
          error: _safeError(error),
        ),
      );
    }
  }

  void setEnabled(bool value) {
    if (state.busy) return;
    emit(state.copyWith(enabled: value, runtimeError: state.runtimeError));
  }

  Future<void> save(BuildContext context) async {
    if (!state.loaded || state.busy) return;
    final l = AppLocalizations.of(context)!;
    final port = int.tryParse(portController.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      emit(
        state.copyWith(
          runtimeError: state.runtimeError,
          error: l.localApiPortInvalid,
        ),
      );
      return;
    }
    emit(state.copyWith(saving: true, runtimeError: state.runtimeError));
    try {
      final value = await _configure(enabled: state.enabled, port: port);
      if (!isPageActive) return;
      portController.text = '${value.port}';
      emit(
        state.copyWith(
          saved: value,
          enabled: value.enabled,
          saving: false,
          listening: _listening(),
          runtimeError: _safeError(_lastError(), token: value.token),
        ),
      );
      if (context.mounted) ContextAlert.settingsSaved(context);
    } catch (error) {
      emit(
        state.copyWith(
          saving: false,
          listening: _listening(),
          runtimeError: _safeError(_lastError()),
          error: _safeError(error),
        ),
      );
    }
  }

  Future<void> resetToken(BuildContext context) async {
    if (!state.loaded || state.busy) return;
    emit(state.copyWith(resetting: true, runtimeError: state.runtimeError));
    try {
      final value = await _resetToken();
      if (!isPageActive) return;
      emit(
        state.copyWith(
          saved: value,
          resetting: false,
          listening: _listening(),
          runtimeError: _safeError(_lastError(), token: value.token),
        ),
      );
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.localApiTokenReset,
        );
      }
    } catch (error) {
      emit(
        state.copyWith(
          resetting: false,
          listening: _listening(),
          runtimeError: _safeError(_lastError()),
          error: _safeError(error),
        ),
      );
    }
  }

  Future<void> copyToken(BuildContext context) async {
    final token = state.saved?.token;
    if (state.busy || token == null || token.isEmpty) return;
    emit(state.copyWith(copying: true, runtimeError: state.runtimeError));
    try {
      await _copyToken(token);
      if (!isPageActive) return;
      emit(state.copyWith(copying: false, runtimeError: state.runtimeError));
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.localApiTokenCopied,
        );
      }
    } catch (_) {
      if (!isPageActive) return;
      emit(
        state.copyWith(
          copying: false,
          runtimeError: state.runtimeError,
          error: context.mounted
              ? AppLocalizations.of(context)!.prototypeCopyFailed
              : null,
        ),
      );
    }
  }

  @override
  void disposePageResources() => portController.dispose();
}
