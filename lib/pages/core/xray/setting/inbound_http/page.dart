import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/setting/inbound_http/controller.dart';
import 'package:onexray/pages/core/xray/setting/inbound_http/params.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class InboundHttpPage extends StatelessWidget {
  final InboundHttpParams params;

  const InboundHttpPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundHttpController(params),
      child: BlocBuilder<InboundHttpController, InboundHttpCubitState>(
        builder: (context, state) {
          final controller = context.read<InboundHttpController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.inboundHttpPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    InboundHttpController controller,
    InboundHttpCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _listenSection(context, controller, state),
                    _authSection(context, controller),
                    _tagSection(context, state),
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

  Widget _listenSection(
    BuildContext context,
    InboundHttpController controller,
    InboundHttpCubitState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: localizations.inboundProxyPageListen,
          value: state.httpState.listen,
        ),
        TextFieldSettingRow(
          controller: controller.portController,
          label: localizations.inboundProxyPagePort,
          keyboardType: TextInputType.number,
        ),
        SettingRow(
          title: localizations.inboundProxyPageProtocol,
          value: state.httpState.protocol.name,
        ),
      ],
    );
  }

  Widget _authSection(BuildContext context, InboundHttpController controller) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundProxyPageAuth,
      children: [
        TextFieldSettingRow(
          controller: controller.userController,
          label: localizations.inboundProxyPageUser,
        ),
        TextFieldSettingRow(
          controller: controller.passController,
          label: localizations.inboundProxyPagePass,
        ),
      ],
    );
  }

  Widget _tagSection(BuildContext context, InboundHttpCubitState state) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.inboundProxyPageTag,
          value: state.httpState.tag.name,
        ),
      ],
    );
  }

  Widget _bottomButton(BuildContext context, InboundHttpController controller) {
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
