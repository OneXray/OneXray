import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';

class SubscriptionEditPageState {
  const SubscriptionEditPageState({
    this.obscureAgeSecretKey = true,
    this.generatingAgeKey = false,
    this.ageKeyPairInvalid = false,
  });

  final bool obscureAgeSecretKey;
  final bool generatingAgeKey;
  final bool ageKeyPairInvalid;

  SubscriptionEditPageState copyWith({
    bool? obscureAgeSecretKey,
    bool? generatingAgeKey,
    bool? ageKeyPairInvalid,
  }) {
    return SubscriptionEditPageState(
      obscureAgeSecretKey: obscureAgeSecretKey ?? this.obscureAgeSecretKey,
      generatingAgeKey: generatingAgeKey ?? this.generatingAgeKey,
      ageKeyPairInvalid: ageKeyPairInvalid ?? this.ageKeyPairInvalid,
    );
  }
}

class SubscriptionEditController extends PageCubit<SubscriptionEditPageState> {
  final SubscriptionEditParams params;
  SubscriptionEditController(this.params)
    : super(const SubscriptionEditPageState()) {
    _init();
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

  Future<void> _init() async {
    final sub = await AppDatabase().subscriptionDao.searchRow(params.id);
    if (!isPageActive) {
      return;
    }
    if (sub != null) {
      nameController.text = sub.name;
      urlController.text = sub.url;
      ageSecretKeyController.text = sub.ageSecretKey ?? '';
      agePublicKeyController.text = sub.agePublicKey ?? '';
      _updateAgeKeyPairValidation();
    }
  }

  Future<void> save(BuildContext context) async {
    if (state.generatingAgeKey) {
      return;
    }
    final name = nameController.text.trim();
    final url = SubscriptionUrl.normalize(urlController.text);
    final check = await SubscriptionValidator.validate(
      name,
      url,
      excludingId: params.id,
    );
    if (!context.mounted) {
      return;
    }
    if (!check.item1) {
      ContextAlert.showToast(context, check.item2);
      return;
    }

    final result = await SubscriptionService().updateSubscription(
      params.id,
      SubscriptionInput(
        name: name,
        url: url,
        ageSecretKey: ageSecretKeyController.text,
        agePublicKey: agePublicKeyController.text,
      ),
    );
    if (!context.mounted) {
      return;
    }
    switch (result) {
      case SubscriptionUpdateResult.success:
        context.pop();
      case SubscriptionUpdateResult.downloadFailed:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionDownloadFailed,
        );
      case SubscriptionUpdateResult.invalidContent:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionAddPageNoConfigs,
        );
      case SubscriptionUpdateResult.invalidAgeSecretKey:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionInvalidAgeSecretKey,
        );
      case SubscriptionUpdateResult.missingAgeSecretKey:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionMissingAgeSecretKey,
        );
      case SubscriptionUpdateResult.decryptFailed:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionDecryptFailed,
        );
      case SubscriptionUpdateResult.contentTooLarge:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionDecryptedTooLarge,
        );
      case SubscriptionUpdateResult.notFound:
      case SubscriptionUpdateResult.writeFailed:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.buttonSaveFailed,
        );
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
}
