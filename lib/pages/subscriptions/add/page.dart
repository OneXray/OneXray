import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/subscriptions/add/controller.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class SubscriptionAddPage extends StatelessWidget {
  const SubscriptionAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionAddController(),
      child: BlocBuilder<SubscriptionAddController, SubscriptionAddPageState>(
        builder: (context, state) {
          final controller = context.read<SubscriptionAddController>();
          return BlocBuilder<AppEventBus, AppEventBusState>(
            buildWhen: (previous, current) =>
                previous.downloading != current.downloading,
            builder: (context, eventState) =>
                _page(context, controller, state, eventState.downloading),
          );
        },
      ),
    );
  }

  Widget _page(
    BuildContext context,
    SubscriptionAddController controller,
    SubscriptionAddPageState state,
    bool downloading,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final autoUpdate = state.autoUpdateState;
    final saveLoading = downloading || state.generatingAgeKey;
    final autoUpdateValue = autoUpdate.subscriptionEnabled
        ? "${localizations.autoUpdatePageEnabled} · ${autoUpdate.subscriptionInterval}"
        : localizations.autoUpdatePageDisabled;
    return SettingsPageScaffold(
      title: localizations.subscriptionAddPageTitle,
      onSave: saveLoading ? null : () => controller.save(context),
      saveLoading: saveLoading,
      saveLabel: localizations.buttonSave,
      body: SubscriptionFormView(
        supportText: localizations.subscriptionAddPageSection,
        nameLabel: localizations.subscriptionAddPageName,
        nameController: controller.nameController,
        urlLabel: localizations.subscriptionAddPageUrl,
        urlController: controller.urlController,
        urlHint: localizations.subscriptionAddPageUrlExample,
        urlHelper: localizations.helpURL,
        autoUpdateTitle: localizations.autoUpdatePageTitle,
        autoUpdateValue: autoUpdateValue,
        onOpenAutoUpdate: () => controller.gotoAutoUpdate(context),
        encryptionTitle: localizations.subscriptionEncryptionSection,
        ageProviderSupportTitle:
            localizations.subscriptionAgeProviderSupportTitle,
        ageProviderSupportDescription:
            localizations.subscriptionAgeProviderSupportDescription,
        ageSecretKeyLabel: localizations.subscriptionAgeSecretKey,
        ageSecretKeyHint: localizations.subscriptionAgeSecretKeyHint,
        ageSecretKeyController: controller.ageSecretKeyController,
        agePublicKeyLabel: localizations.subscriptionAgePublicKey,
        agePublicKeyHint: localizations.subscriptionAgePublicKeyHint,
        agePublicKeyController: controller.agePublicKeyController,
        ageKeyPairErrorText: state.ageKeyPairInvalid
            ? localizations.subscriptionInvalidAgeSecretKey
            : null,
        onAgeKeyChanged: controller.ageKeyChanged,
        obscureAgeSecretKey: state.obscureAgeSecretKey,
        revealAgeSecretKeyLabel: localizations.subscriptionRevealAgeKey,
        hideAgeSecretKeyLabel: localizations.subscriptionHideAgeKey,
        generateAgeKeyLabel: localizations.subscriptionGenerateAgeKey,
        generateAgeX25519KeyLabel:
            localizations.subscriptionGenerateAgeX25519Key,
        generateAgeHybridKeyLabel:
            localizations.subscriptionGenerateAgeHybridKey,
        clearAgeKeyLabel: localizations.subscriptionClearAgeKey,
        onToggleAgeSecretKeyVisibility: controller.toggleAgeSecretKeyVisibility,
        onGenerateAgeKey: (keyType) =>
            controller.generateAgeKey(context, keyType),
        onClearAgeKey: controller.clearAgeKeyPair,
        generatingAgeKey: state.generatingAgeKey,
      ),
    );
  }
}
