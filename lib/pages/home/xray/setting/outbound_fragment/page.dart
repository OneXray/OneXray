import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class OutboundFragmentPage extends StatelessWidget {
  final OutboundFragmentParams params;

  const OutboundFragmentPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundFragmentController(params),
      child:
          BlocBuilder<OutboundFragmentController, OutboundFragmentCubitState>(
            builder: (context, state) {
              final controller = context.read<OutboundFragmentController>();
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    AppLocalizations.of(context)!.outboundFragmentPageTitle,
                  ),
                ),
                body: SafeArea(child: _body(context, controller, state)),
              );
            },
          ),
    );
  }

  Widget _body(
    BuildContext context,
    OutboundFragmentController controller,
    OutboundFragmentCubitState state,
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
                    _protocolSection(context, controller, state),
                    _settingSection(context, controller),
                    _tagSection(context, controller, state),
                    if (AppPlatform.isLinux || AppPlatform.isWindows)
                      _sockoptSection(context, controller, state),
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

  Widget _protocolSection(
    BuildContext context,
    OutboundFragmentController controller,
    OutboundFragmentCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.outboundFragmentPageProtocol,
          value: state.fragmentState.protocol.name,
        ),
      ],
    );
  }

  Widget _settingSection(
    BuildContext context,
    OutboundFragmentController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundFragmentPageSettings,
      children: [
        _packets(context, controller),
        _length(context, controller),
        _interval(context, controller),
      ],
    );
  }

  Widget _packets(BuildContext context, OutboundFragmentController controller) {
    return TextFieldSettingRow(
      controller: controller.packetsController,
      label: AppLocalizations.of(context)!.outboundFragmentPagePackets,
      hintText: AppLocalizations.of(context)!.outboundFragmentPagePackets,
    );
  }

  Widget _length(BuildContext context, OutboundFragmentController controller) {
    return TextFieldSettingRow(
      controller: controller.lengthController,
      label: AppLocalizations.of(context)!.outboundFragmentPageLength,
      hintText: AppLocalizations.of(context)!.outboundFragmentPageLength,
    );
  }

  Widget _interval(
    BuildContext context,
    OutboundFragmentController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.intervalController,
      label: AppLocalizations.of(context)!.outboundFragmentPageInterval,
      hintText: AppLocalizations.of(context)!.outboundFragmentPageInterval,
    );
  }

  Widget _tagSection(
    BuildContext context,
    OutboundFragmentController controller,
    OutboundFragmentCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.outboundFragmentPageTag,
          value: state.fragmentState.tag.name,
        ),
      ],
    );
  }

  Widget _sockoptSection(
    BuildContext context,
    OutboundFragmentController controller,
    OutboundFragmentCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundFragmentPageSockopt,
      children: [_interface(context, controller, state)],
    );
  }

  Widget _interface(
    BuildContext context,
    OutboundFragmentController controller,
    OutboundFragmentCubitState state,
  ) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.outboundFragmentPageInterface,
      value: state.fragmentState.interface,
      onTap: () => controller.editInterface(context),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    OutboundFragmentController controller,
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
