import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';

class OutboundFragmentPage extends StatelessWidget {
  final OutboundFragmentParams params;

  const OutboundFragmentPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundFragmentController(params),
      child: BlocBuilder<OutboundFragmentController, OutboundFragmentCubitState>(
        builder: (context, state) {
          final controller = context.read<OutboundFragmentController>();
          return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.outboundFragmentPageTitle),
        ),
        body: SafeArea(child: _body(context, controller, state)),
      );
        },
      ),
    );
  }

  Widget _body(BuildContext context, OutboundFragmentController controller, OutboundFragmentCubitState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
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
    );
  }

  Widget _protocolSection(
    BuildContext context,
    OutboundFragmentController controller, OutboundFragmentCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.outboundFragmentPageProtocol,
            detail: state.fragmentState.protocol.name,
          ),
        ],
      ),
    );
  }

  Widget _settingSection(
    BuildContext context,
    OutboundFragmentController controller,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundFragmentPageSettings,
      child: Column(
        children: [
          _packets(context, controller),
          _length(context, controller),
          _interval(context, controller),
        ],
      ),
    );
  }

  Widget _packets(BuildContext context, OutboundFragmentController controller) {
    return TextField(
      controller: controller.packetsController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundFragmentPagePackets),
        hintText: AppLocalizations.of(context)!.outboundFragmentPagePackets,
      ),
    );
  }

  Widget _length(BuildContext context, OutboundFragmentController controller) {
    return TextField(
      controller: controller.lengthController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundFragmentPageLength),
        hintText: AppLocalizations.of(context)!.outboundFragmentPageLength,
      ),
    );
  }

  Widget _interval(
    BuildContext context,
    OutboundFragmentController controller,
  ) {
    return TextField(
      controller: controller.intervalController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundFragmentPageInterval),
        hintText: AppLocalizations.of(context)!.outboundFragmentPageInterval,
      ),
    );
  }

  Widget _tagSection(
    BuildContext context,
    OutboundFragmentController controller, OutboundFragmentCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.outboundFragmentPageTag,
            detail: state.fragmentState.tag.name,
          ),
        ],
      ),
    );
  }

  Widget _sockoptSection(
    BuildContext context,
    OutboundFragmentController controller, OutboundFragmentCubitState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundFragmentPageSockopt,
      child: Column(children: [_interface(context, controller, state)]),
    );
  }

  Widget _interface(
    BuildContext context,
    OutboundFragmentController controller, OutboundFragmentCubitState state) {
    return InkWell(
      onTap: () => controller.editInterface(context),
      child: TextRow(
        title: AppLocalizations.of(context)!.outboundFragmentPageInterface,
        detail: state.fragmentState.interface,
      ),
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
