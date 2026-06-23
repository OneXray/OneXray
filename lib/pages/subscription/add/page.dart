import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/subscription/add/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class SubscriptionAddPage extends StatelessWidget {
  const SubscriptionAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionAddController(),
      child: Builder(
        builder: (context) {
          final controller = context.read<SubscriptionAddController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(
                AppLocalizations.of(context)!.subscriptionAddPageTitle,
              ),
            ),
            body: SafeArea(child: _body(context, controller)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, SubscriptionAddController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SettingSection(
                  title: AppLocalizations.of(
                    context,
                  )!.subscriptionAddPageSection,
                  children: [
                    _name(context, controller),
                    _url(context, controller),
                    _autoUpdate(context),
                  ],
                ),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _name(BuildContext context, SubscriptionAddController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.subscriptionAddPageName,
      hintText: AppLocalizations.of(context)!.subscriptionAddPageName,
    );
  }

  Widget _url(BuildContext context, SubscriptionAddController controller) {
    return TextFieldSettingRow(
      controller: controller.urlController,
      label: AppLocalizations.of(context)!.subscriptionAddPageUrl,
      hintText: AppLocalizations.of(context)!.subscriptionAddPageUrlExample,
      helperText: AppLocalizations.of(context)!.helpURL,
    );
  }

  Widget _autoUpdate(BuildContext context) {
    return SettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageTitle,
      onTap: () => context.push(RouterPath.autoUpdate),
      showChevron: true,
    );
  }

  Widget _bottomButton(
    BuildContext context,
    SubscriptionAddController controller,
  ) {
    return BottomView(
      child: Row(
        children: [
          BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, state) =>
                _saveButton(context, controller, state),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(
    BuildContext context,
    SubscriptionAddController controller,
    AppEventBusState state,
  ) {
    final downloading = state.downloading;
    if (downloading) {
      return const CircularProgressIndicator();
    } else {
      return Expanded(
        child: PrimaryBottomButton(
          title: AppLocalizations.of(context)!.buttonSave,
          callback: () => controller.save(context),
        ),
      );
    }
  }
}
