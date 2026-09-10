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

String? nativeOperationFailureTitle(AppLocalizations l, String? code) =>
    switch (code) {
      'startFailed' => l.prototypeConnectionFailed,
      'stopFailed' => l.actionResult(l.prototypeDisconnect, l.resultFailed),
      'startTimeout' => '${l.prototypeConnect} · ${l.prototypeTimeout}',
      'stopTimeout' => '${l.prototypeDisconnect} · ${l.prototypeTimeout}',
      _ => null,
    };

String? _nativeOperationFailure(AppLocalizations l, Object? error) =>
    switch (error) {
      AppFailure() =>
        nativeOperationFailureTitle(l, error.code) ??
            _nativeOperationFailure(l, error.cause),
      _ => null,
    };
