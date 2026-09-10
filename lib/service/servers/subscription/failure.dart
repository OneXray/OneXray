import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/shared/failure.dart';

String subscriptionFailureMessage(
  AppLocalizations l,
  SubscriptionUpdateResult status, {
  Object? error,
  bool updating = false,
}) => appFailureMessage(
  l,
  error ??
      (status == SubscriptionUpdateResult.notFound
          ? const AppFailure(FailureCategory.conflict, 'notFound')
          : null),
  operation: switch (status) {
    SubscriptionUpdateResult.downloadFailed => l.subscriptionDownloadFailed,
    SubscriptionUpdateResult.invalidAgeSecretKey =>
      l.subscriptionInvalidAgeSecretKey,
    SubscriptionUpdateResult.missingAgeSecretKey =>
      l.subscriptionMissingAgeSecretKey,
    SubscriptionUpdateResult.decryptFailed => l.subscriptionDecryptFailed,
    SubscriptionUpdateResult.contentTooLarge => l.subscriptionDecryptedTooLarge,
    SubscriptionUpdateResult.invalidContent =>
      updating
          ? l.prototypeNoAvailableEntries
          : l.prototypeSubscriptionNotAdded,
    SubscriptionUpdateResult.notFound => l.prototypeTemporarilyUnavailable,
    _ => l.buttonSaveFailed,
  },
);
