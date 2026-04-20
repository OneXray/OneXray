import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/subscription/edit/controller.dart';
import 'package:onexray/pages/subscription/edit/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';

class SubscriptionEditPage extends StatelessWidget {
  final SubscriptionEditParams params;
  const SubscriptionEditPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionEditController(params),
      child: BlocBuilder<SubscriptionEditController, SubscriptionEditState>(
        builder: (context, state) {
          final controller = context.read<SubscriptionEditController>();
          return Scaffold(
            appBar: AppBar(
              title:
                  Text(AppLocalizations.of(context)!.subscriptionAddPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SubscriptionEditController controller,
    SubscriptionEditState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SectionView(
                title: AppLocalizations.of(context)!.subscriptionAddPageSection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _name(context, controller),
                    _url(context, state),
                  ],
                ),
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _name(BuildContext context, SubscriptionEditController controller) {
    return TextField(
      controller: controller.nameController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.subscriptionAddPageName),
        hintText: AppLocalizations.of(context)!.subscriptionAddPageName,
      ),
    );
  }

  Widget _url(BuildContext context, SubscriptionEditState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.subscriptionAddPageUrl,
          style: TextStyle(
            fontSize: 12,
            color: ColorManager.secondaryText(context),
          ),
        ),
        Text(state.url),
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    SubscriptionEditController controller,
  ) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.buttonSave,
              callback: () => controller.save(context),
            ),
          ),
        ],
      ),
    );
  }
}
