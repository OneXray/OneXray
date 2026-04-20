import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/raw/controller.dart';
import 'package:onexray/pages/home/xray/raw/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class XrayRawPage extends StatefulWidget {
  final XrayRawParams params;

  const XrayRawPage({super.key, required this.params});

  @override
  State<XrayRawPage> createState() => _XrayRawPageState();
}

class _XrayRawPageState extends State<XrayRawPage> {
  late final XrayRawController controller;

  @override
  void initState() {
    super.initState();
    controller = XrayRawController(widget.params);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.outboundPageTitle),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: controller.controller,
              decoration: InputDecoration(border: InputBorder.none),
              maxLines: null,
            ),
          ),
          _bottomButton(context),
        ],
      ),
    );
  }

  Widget _bottomButton(BuildContext context) {
    return BottomView(
      child: Row(
        spacing: 12,
        children: [
          BlocBuilder<AppEventBus, AppEventBusState>(
            bloc: AppEventBus.instance,
            builder: (context, eventState) =>
                _bottomPingButton(context, eventState),
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

  Widget _bottomPingButton(BuildContext context, AppEventBusState eventState) {
    final pinging = eventState.pinging;
    if (pinging) {
      return const CircularProgressIndicator();
    } else {
      return Expanded(
        child: SecondaryBottomButton(
          title: AppLocalizations.of(context)!.outboundPageRealPing,
          callback: () => controller.realPing(context),
        ),
      );
    }
  }
}
