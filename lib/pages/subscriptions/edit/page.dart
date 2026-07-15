import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/subscriptions/edit/controller.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/widget/settings_page.dart';

class SubscriptionEditPage extends StatelessWidget {
  final SubscriptionEditParams params;
  const SubscriptionEditPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionEditController(params),
      child: BlocBuilder<SubscriptionEditController, SubscriptionEditPageState>(
        builder: (context, state) {
          final controller = context.read<SubscriptionEditController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.subscriptionEditPageTitle,
            onSave: () => controller.save(context),
            saveLabel: localizations.buttonSave,
            body: SubscriptionFormView(
              supportText: localizations.subscriptionAddPageSection,
              nameLabel: localizations.subscriptionAddPageName,
              nameController: controller.nameController,
              urlLabel: localizations.subscriptionAddPageUrl,
              readOnlyUrl: state.url,
            ),
          );
        },
      ),
    );
  }
}
