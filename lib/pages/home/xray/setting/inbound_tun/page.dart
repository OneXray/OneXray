import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/inbound_tun/controller.dart';
import 'package:onexray/pages/home/xray/setting/inbound_tun/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';

class InboundTunPage extends StatelessWidget {
  final InboundTunParams params;

  const InboundTunPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundTunController(params),
      child: BlocBuilder<InboundTunController, InboundTunCubitState>(
        builder: (context, state) {
          final controller = context.read<InboundTunController>();
          return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.inboundTunPageTitle),
        ),
        body: SafeArea(child: _body(context, controller, state)),
      );
        },
      ),
    );
  }

  Widget _body(BuildContext context, InboundTunController controller, InboundTunCubitState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _listenSection(context, controller, state),
                  _settingsSection(context, controller, state),
                  _tagSection(context, controller, state),
                  _sniffingSection(context, controller),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _listenSection(BuildContext context, InboundTunController controller, InboundTunCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.inboundTunPageListen,
            detail: state.tunState.listen,
          ),
          TextRow(
            title: AppLocalizations.of(context)!.inboundTunPageProtocol,
            detail: state.tunState.protocol.name,
          ),
        ],
      ),
    );
  }

  Widget _settingsSection(
    BuildContext context,
    InboundTunController controller, InboundTunCubitState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.inboundTunPageSettings,
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.inboundTunPageSettingsName,
            detail: state.tunState.settings.name,
          ),
          TextRow(
            title: AppLocalizations.of(context)!.inboundTunPageSettingsMTU,
            detail: "${state.tunState.settings.mtu}",
          ),
        ],
      ),
    );
  }

  Widget _tagSection(BuildContext context, InboundTunController controller, InboundTunCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.inboundTunPageTag,
            detail: state.tunState.tag.name,
          ),
        ],
      ),
    );
  }

  Widget _sniffingSection(
    BuildContext context,
    InboundTunController controller,
  ) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          ListTile(
            onTap: () => controller.editSniffing(context),
            title: Text(AppLocalizations.of(context)!.inboundTunPageSniffing),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _bottomButton(BuildContext context, InboundTunController controller) {
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
