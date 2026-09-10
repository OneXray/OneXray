import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';

export 'package:onexray/core/errors/failure.dart';

/// Reuse approved UI copy; diagnostic details remain in the source language.
String appFailureMessage(
  AppLocalizations l,
  Object? error, {
  String? operation,
}) {
  final title =
      _nativeOperationFailure(l, error) ??
      operation ??
      switch (failureCategory(error)) {
        FailureCategory.configuration => 'Xray · ${l.resultFailed}',
        FailureCategory.network => '${l.prototypeDownload} · ${l.resultFailed}',
        FailureCategory.permission => l.prototypePermissionNotGranted,
        _ => l.resultFailed,
      };
  final detail = failureDetails(error).trim();
  return detail.isEmpty || detail == title ? title : '$title\n$detail';
}

String? _nativeOperationFailure(AppLocalizations l, Object? error) =>
    switch (error) {
      AppFailure(code: 'startFailed') => l.prototypeConnectionFailed,
      AppFailure(code: 'stopFailed') => l.actionResult(
        l.prototypeDisconnect,
        l.resultFailed,
      ),
      AppFailure(code: 'startTimeout') =>
        '${l.prototypeConnect} · ${l.prototypeTimeout}',
      AppFailure(code: 'stopTimeout') =>
        '${l.prototypeDisconnect} · ${l.prototypeTimeout}',
      AppFailure() => _nativeOperationFailure(l, error.cause),
      _ => null,
    };
