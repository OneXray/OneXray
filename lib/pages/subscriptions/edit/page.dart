import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/subscriptions/edit/controller.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class SubscriptionEditPage extends StatelessWidget {
  final SubscriptionEditParams params;
  const SubscriptionEditPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionEditController(params),
      child: BlocBuilder<SubscriptionEditController, SubscriptionEditPageState>(
        builder: (context, pageState) {
          final controller = context.read<SubscriptionEditController>();
          return BlocBuilder<AppEventBus, AppEventBusState>(
            bloc: AppEventBus.instance,
            buildWhen: (previous, current) =>
                previous.downloading != current.downloading,
            builder: (context, state) {
              final localizations = AppLocalizations.of(context)!;
              final saveLoading =
                  state.downloading || pageState.generatingAgeKey;
              return SettingsPageScaffold(
                title: localizations.subscriptionEditPageTitle,
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
                  ageKeyPairErrorText: pageState.ageKeyPairInvalid
                      ? localizations.subscriptionInvalidAgeSecretKey
                      : null,
                  onAgeKeyChanged: controller.ageKeyChanged,
                  obscureAgeSecretKey: pageState.obscureAgeSecretKey,
                  revealAgeSecretKeyLabel:
                      localizations.subscriptionRevealAgeKey,
                  hideAgeSecretKeyLabel: localizations.subscriptionHideAgeKey,
                  generateAgeKeyLabel: localizations.subscriptionGenerateAgeKey,
                  generateAgeX25519KeyLabel:
                      localizations.subscriptionGenerateAgeX25519Key,
                  generateAgeHybridKeyLabel:
                      localizations.subscriptionGenerateAgeHybridKey,
                  clearAgeKeyLabel: localizations.subscriptionClearAgeKey,
                  onToggleAgeSecretKeyVisibility:
                      controller.toggleAgeSecretKeyVisibility,
                  onGenerateAgeKey: (keyType) =>
                      controller.generateAgeKey(context, keyType),
                  onClearAgeKey: controller.clearAgeKeyPair,
                  generatingAgeKey: pageState.generatingAgeKey,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
