import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';

class SubscriptionAddPageState {
  const SubscriptionAddPageState({
    required this.autoUpdateState,
    this.obscureAgeSecretKey = true,
    this.generatingAgeKey = false,
    this.ageKeyPairInvalid = false,
  });

  factory SubscriptionAddPageState.initial() =>
      SubscriptionAddPageState(autoUpdateState: AutoUpdateState());

  final AutoUpdateState autoUpdateState;
  final bool obscureAgeSecretKey;
  final bool generatingAgeKey;
  final bool ageKeyPairInvalid;

  SubscriptionAddPageState copyWith({
    AutoUpdateState? autoUpdateState,
    bool? obscureAgeSecretKey,
    bool? generatingAgeKey,
    bool? ageKeyPairInvalid,
  }) {
    return SubscriptionAddPageState(
      autoUpdateState: autoUpdateState ?? this.autoUpdateState,
      obscureAgeSecretKey: obscureAgeSecretKey ?? this.obscureAgeSecretKey,
      generatingAgeKey: generatingAgeKey ?? this.generatingAgeKey,
      ageKeyPairInvalid: ageKeyPairInvalid ?? this.ageKeyPairInvalid,
    );
  }
}

class SubscriptionAddController extends PageCubit<SubscriptionAddPageState> {
  SubscriptionAddController() : super(SubscriptionAddPageState.initial()) {
    _readAutoUpdateState();
  }

  final nameController = TextEditingController();
  final urlController = TextEditingController();
  final ageSecretKeyController = TextEditingController();
  final agePublicKeyController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
    urlController.dispose();
    ageSecretKeyController.dispose();
    agePublicKeyController.dispose();
  }

  Future<void> save(BuildContext context) async {
    if (state.generatingAgeKey) {
      return;
    }
    final name = nameController.text.trim();
    final url = SubscriptionUrl.normalize(urlController.text);
    final check = await SubscriptionValidator.validate(name, url);
    if (check.item1) {
      final result = await SubscriptionService().insertSubscription(
        SubscriptionInput(
          name: name,
          url: url,
          ageSecretKey: ageSecretKeyController.text,
          agePublicKey: agePublicKeyController.text,
        ),
        true,
      );
      if (context.mounted) {
        if (result.success) {
          context.pop();
        } else {
          _showSaveError(context, result.status);
        }
      }
    } else {
      if (context.mounted) {
        ContextAlert.showToast(context, check.item2);
      }
    }
  }

  void toggleAgeSecretKeyVisibility() {
    emit(state.copyWith(obscureAgeSecretKey: !state.obscureAgeSecretKey));
  }

  void clearAgeKeyPair() {
    ageSecretKeyController.clear();
    agePublicKeyController.clear();
    _updateAgeKeyPairValidation();
  }

  void ageKeyChanged(String _) {
    _updateAgeKeyPairValidation();
  }

  Future<void> generateAgeKey(BuildContext context, AgeKeyType keyType) async {
    if (state.generatingAgeKey) {
      return;
    }
    if (ageSecretKeyController.text.trim().isNotEmpty ||
        agePublicKeyController.text.trim().isNotEmpty) {
      final localizations = AppLocalizations.of(context)!;
      final confirmed = await ContextAlert.showConfirmDialog(
        context,
        title: localizations.subscriptionReplaceAgeKeyTitle,
        content: localizations.subscriptionReplaceAgeKeyMessage,
        confirmLabel: localizations.subscriptionGenerateAgeKey,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }

    emit(state.copyWith(generatingAgeKey: true));
    try {
      final pair = await AppHostApi().generateAgeKeyPair(keyType: keyType);
      if (isPageActive) {
        ageSecretKeyController.text = pair.secretKey ?? '';
        agePublicKeyController.text = pair.publicKey ?? '';
        emit(state.copyWith(ageKeyPairInvalid: false));
      }
    } catch (_) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionGenerateAgeKeyFailed,
        );
      }
    } finally {
      if (isPageActive) {
        emit(state.copyWith(generatingAgeKey: false));
      }
    }
  }

  void _updateAgeKeyPairValidation() {
    final hasSecretKey = ageSecretKeyController.text.trim().isNotEmpty;
    final hasPublicKey = agePublicKeyController.text.trim().isNotEmpty;
    final invalid = hasSecretKey != hasPublicKey;
    if (state.ageKeyPairInvalid != invalid) {
      emit(state.copyWith(ageKeyPairInvalid: invalid));
    }
  }

  void _showSaveError(BuildContext context, SubscriptionUpdateResult result) {
    final localizations = AppLocalizations.of(context)!;
    final message = switch (result) {
      SubscriptionUpdateResult.downloadFailed =>
        localizations.subscriptionDownloadFailed,
      SubscriptionUpdateResult.invalidAgeSecretKey =>
        localizations.subscriptionInvalidAgeSecretKey,
      SubscriptionUpdateResult.missingAgeSecretKey =>
        localizations.subscriptionMissingAgeSecretKey,
      SubscriptionUpdateResult.decryptFailed =>
        localizations.subscriptionDecryptFailed,
      SubscriptionUpdateResult.contentTooLarge =>
        localizations.subscriptionDecryptedTooLarge,
      SubscriptionUpdateResult.invalidContent =>
        localizations.subscriptionAddPageNoConfigs,
      _ => localizations.buttonAddFailed,
    };
    ContextAlert.showToast(context, message);
  }

  Future<void> gotoAutoUpdate(BuildContext context) async {
    await context.pushScoped(AppSecondaryDestination.autoUpdate);
    await _readAutoUpdateState();
  }

  Future<void> _readAutoUpdateState() async {
    final autoUpdateState = AutoUpdateState();
    await autoUpdateState.readFromPreferences();
    if (isPageActive) {
      emit(state.copyWith(autoUpdateState: autoUpdateState));
    }
  }
}
