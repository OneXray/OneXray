import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/controller.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/service/xray/outbound/enum.dart';

class OutboundXhttpPage extends StatelessWidget {
  final OutboundXhttpParams params;

  const OutboundXhttpPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundXhttpController(params),
      child: BlocBuilder<OutboundXhttpController, OutboundXhttpState>(
        builder: (context, state) {
          final controller = context.read<OutboundXhttpController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.outboundXhttpPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, OutboundXhttpController controller, OutboundXhttpState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _headersSection(context, controller, state),
                  _xPaddingBytesSection(context, controller, state),
                  _xmuxSection(context, controller),
                  if (state.mode != XhttpMode.streamOne)
                    _downloadSettingsSection(context, controller),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _headersSection(BuildContext context, OutboundXhttpController controller, OutboundXhttpState state) {
    final headerViews = <Widget>[];
    for (final header in state.headers) {
      final key = TextField(
        controller: header.key,
        decoration: InputDecoration(
          label: Text(AppLocalizations.of(context)!.outboundXhttpPageHeadersKey),
          hintText: AppLocalizations.of(context)!.outboundXhttpPageHeadersKey,
        ),
      );
      final value = TextField(
        controller: header.value,
        decoration: InputDecoration(
          label: Text(AppLocalizations.of(context)!.outboundXhttpPageHeadersValue),
          hintText: AppLocalizations.of(context)!.outboundXhttpPageHeadersValue,
        ),
      );
      headerViews.add(key);
      headerViews.add(value);
    }
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.outboundXhttpPageHeaders),
              IconButton(
                onPressed: () => controller.appendHeader(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (headerViews.isNotEmpty) Column(children: headerViews),
        ],
      ),
    );
  }

  Widget _xPaddingBytesSection(BuildContext context, OutboundXhttpController controller, OutboundXhttpState state) {
    return SectionView(
      title: "",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _xPaddingBytes(context, controller),
          _noGRPCHeader(context, controller, state),
          _scMaxEachPostBytes(context, controller),
          _scMinPostsIntervalMs(context, controller),
        ],
      ),
    );
  }

  Widget _xPaddingBytes(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.xPaddingBytesController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXPaddingBytes),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXPaddingBytes,
      ),
    );
  }

  Widget _noGRPCHeader(BuildContext context, OutboundXhttpController controller, OutboundXhttpState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundXhttpPageNoGRPCHeader),
        Switch(
          value: state.extraState.noGRPCHeader,
          onChanged: (value) => controller.updateNoGRPCHeader(value),
        ),
      ],
    );
  }

  Widget _scMaxEachPostBytes(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.scMaxEachPostBytesController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageScMaxEachPostBytes),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageScMaxEachPostBytes,
      ),
    );
  }

  Widget _scMinPostsIntervalMs(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.scMinPostsIntervalMsController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageScMinPostsIntervalMs),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageScMinPostsIntervalMs,
      ),
    );
  }

  Widget _xmuxSection(BuildContext context, OutboundXhttpController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundXhttpPageXmux,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _maxConcurrency(context, controller),
          _maxConnections(context, controller),
          _cMaxReuseTimes(context, controller),
          _hMaxReusableSecs(context, controller),
          _hMaxRequestTimes(context, controller),
          _hKeepAlivePeriod(context, controller),
        ],
      ),
    );
  }

  Widget _maxConcurrency(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.maxConcurrencyController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConcurrency),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConcurrency,
      ),
    );
  }

  Widget _maxConnections(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.maxConnectionsController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConnections),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConnections,
      ),
    );
  }

  Widget _cMaxReuseTimes(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.cMaxReuseTimesController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxCMaxReuseTimes),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxCMaxReuseTimes,
      ),
    );
  }

  Widget _hMaxReusableSecs(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.hMaxReusableSecsController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxReusableSecs),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxReusableSecs,
      ),
    );
  }

  Widget _hMaxRequestTimes(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.hMaxRequestTimesController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxRequestTimes),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxRequestTimes,
      ),
    );
  }

  Widget _hKeepAlivePeriod(BuildContext context, OutboundXhttpController controller) {
    return TextField(
      controller: controller.hKeepAlivePeriodController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxHKeepAlivePeriod),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxHKeepAlivePeriod,
      ),
    );
  }

  Widget _downloadSettingsSection(BuildContext context, OutboundXhttpController controller) {
    return SectionView(
      title: "",
      child: InkWell(
        onTap: () => controller.editXhttpDownloadSettings(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.outboundXhttpPageDownloadSettings),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomButton(BuildContext context, OutboundXhttpController controller) {
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
