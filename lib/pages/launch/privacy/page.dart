import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/launch/privacy/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PrivacyController(),
      child: BlocBuilder<PrivacyController, PrivacyState>(
        builder: (context, state) {
          final controller = context.read<PrivacyController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.privacyPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    PrivacyState state,
    PrivacyController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: Markdown(
              data: state.md,
              onTapLink: (_, href, _) => controller.openUrl(href),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _bottomButton(BuildContext context, PrivacyController controller) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.privacyPageAccept,
              callback: () => controller.accept(context),
            ),
          ),
        ],
      ),
    );
  }
}
