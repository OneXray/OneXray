import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/raw/controller.dart';
import 'package:onexray/pages/core/xray/raw/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class XrayRawPage extends StatelessWidget {
  final XrayRawParams params;

  const XrayRawPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayRawController(params),
      child: Builder(
        builder: (context) {
          final controller = context.read<XrayRawController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.xrayRawPageTitle),
              actions: [
                IconMenuPicker(
                  icon: Icons.file_upload_outlined,
                  menus: [IconMenuId.pickFile, IconMenuId.readPasteboard],
                  callback: (menuId) =>
                      controller.importAction(context, menuId),
                ),
              ],
            ),
            body: SafeArea(child: _body(context, controller)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, XrayRawController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        desktopMaxWidth: 900,
        adaptiveBreakpoint: 840,
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: controller.controller,
                decoration: InputDecoration(border: InputBorder.none),
                maxLines: null,
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton(BuildContext context, XrayRawController controller) {
    return BottomView(
      child: Row(
        spacing: 12,
        children: [
          BlocBuilder<AppEventBus, AppEventBusState>(
            bloc: AppEventBus.instance,
            builder: (context, eventState) =>
                _bottomPingButton(context, controller, eventState),
          ),
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

  Widget _bottomPingButton(
    BuildContext context,
    XrayRawController controller,
    AppEventBusState eventState,
  ) {
    final pinging = eventState.pinging;
    return Expanded(
      child: SecondaryBottomButton(
        title: AppLocalizations.of(context)!.outboundPageRealPing,
        callback: pinging ? null : () => controller.realPing(context),
        loading: pinging,
      ),
    );
  }
}
