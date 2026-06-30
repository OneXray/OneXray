import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/setting/inbound_proxy/controller.dart';
import 'package:onexray/pages/core/xray/setting/inbound_proxy/params.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class InboundProxyPage extends StatelessWidget {
  final InboundProxyParams params;

  const InboundProxyPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundProxyController(params),
      child: BlocBuilder<InboundProxyController, InboundProxyCubitState>(
        builder: (context, state) {
          final controller = context.read<InboundProxyController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.inboundProxyPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    InboundProxyController controller,
    InboundProxyCubitState state,
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
    InboundProxyController controller,
    InboundProxyCubitState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: localizations.inboundProxyPageListen,
          value: state.proxyState.listen,
        ),
        TextFieldSettingRow(
          controller: controller.portController,
          label: localizations.inboundProxyPagePort,
          keyboardType: TextInputType.number,
        ),
        SettingRow(
          title: localizations.inboundProxyPageProtocol,
          value: state.proxyState.protocol.name,
        ),
      ],
    );
  }

  Widget _authSection(BuildContext context, InboundProxyController controller) {
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

  Widget _tagSection(BuildContext context, InboundProxyCubitState state) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.inboundProxyPageTag,
          value: state.proxyState.tag.name,
        ),
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    InboundProxyController controller,
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
