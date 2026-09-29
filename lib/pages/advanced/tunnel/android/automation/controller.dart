import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/advanced/tunnel/android/automation/service.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:url_launcher/url_launcher.dart';

class AutomationPageState {
  const AutomationPageState({
    this.saved,
    this.loading = true,
    this.writing,
    this.copying = const {},
    this.openingHelp = false,
    this.error,
  });
  final AndroidAutomationSettings? saved;
  final bool loading;
  final String? writing;
  final Set<String> copying;
  final bool openingHelp;
  final String? error;

  AutomationPageState copyWith({
    AndroidAutomationSettings? saved,
    bool? loading,
    String? writing,
    bool clearWriting = false,
    Set<String>? copying,
    bool? openingHelp,
    String? error,
  }) => AutomationPageState(
    saved: saved ?? this.saved,
    loading: loading ?? this.loading,
    writing: clearWriting ? null : writing ?? this.writing,
    copying: copying ?? this.copying,
    openingHelp: openingHelp ?? this.openingHelp,
    error: error,
  );
}

class AutomationController extends PageCubit<AutomationPageState> {
  AutomationController({
    AndroidAutomationService? service,
    Future<void> Function(String)? copy,
  }) : _service = service ?? AndroidAutomationService(),
       _copy =
           copy ?? ((value) => Clipboard.setData(ClipboardData(text: value))),
       super(const AutomationPageState()) {
    load();
  }

  final AndroidAutomationService _service;
  final Future<void> Function(String) _copy;

  String _safeError(Object error) =>
      failureDetails(error)
          .replaceAll(RegExp(r'ox_[A-Za-z0-9_-]{43}'), '[redacted]');

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    try {
      emit(state.copyWith(saved: await _service.read(), loading: false));
    } catch (error) {
      emit(state.copyWith(loading: false, error: _safeError(error)));
    }
  }

  Future<void> setEnabled(BuildContext context, bool value) =>
      _write(context, 'enable', () => _service.setEnabled(value));

  Future<void> resetToken(BuildContext context) async {
    if (state.writing != null || state.saved?.enabled != true) return;
    final l = AppLocalizations.of(context)!;
    if (!await ContextAlert.showConfirmDialog(
      context,
      title: l.localApiResetToken,
      content: l.automationResetConfirm,
    )) {
      return;
    }
    if (!isPageActive || !context.mounted) return;
    await _write(context, 'reset', _service.resetToken);
  }

  Future<void> _write(
    BuildContext context,
    String operation,
    Future<AndroidAutomationSettings> Function() save,
  ) async {
    if (state.writing != null || state.saved == null) return;
    emit(state.copyWith(writing: operation));
    try {
      final saved = await save();
      emit(state.copyWith(saved: saved, clearWriting: true));
      if (isPageActive && context.mounted) ContextAlert.settingsSaved(context);
    } catch (error) {
      emit(state.copyWith(clearWriting: true, error: _safeError(error)));
    }
  }

  Future<void> copy(BuildContext context, String key, String value) async {
    if (state.copying.contains(key)) return;
    emit(state.copyWith(copying: {...state.copying, key}));
    try {
      await _copy(value);
      emit(state.copyWith(copying: {...state.copying}..remove(key)));
      if (isPageActive && context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.automationCopied,
        );
      }
    } catch (_) {
      emit(
        state.copyWith(
          copying: {...state.copying}..remove(key),
          error: context.mounted
              ? AppLocalizations.of(context)!.prototypeCopyFailed
              : null,
        ),
      );
    }
  }

  Future<void> openHelp(BuildContext context) async {
    if (state.openingHelp) return;
    emit(state.copyWith(openingHelp: true));
    final language = Localizations.localeOf(context).languageCode;
    final prefix = switch (language) {
      'zh' => '/zh',
      'ru' => '/ru',
      _ => '',
    };
    try {
      if (!await launchUrl(
        Uri.parse(
          'https://onexray.com$prefix/docs/advanced/android/#automation',
        ),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('No application could open this link.');
      }
      emit(state.copyWith(openingHelp: false));
    } catch (error) {
      emit(state.copyWith(openingHelp: false, error: _safeError(error)));
    }
  }
}
