import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/download_settings/controller.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/download_settings/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';
import 'package:onexray/service/xray/outbound/enum.dart';

class XhttpDownloadSettingsPage extends StatelessWidget {
  final XhttpDownloadSettingsParams params;

  const XhttpDownloadSettingsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XhttpDownloadSettingsController(params),
      child: BlocBuilder<XhttpDownloadSettingsController, XhttpDownloadSettingsState>(
        builder: (context, state) {
          final controller = context.read<XhttpDownloadSettingsController>();
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

  Widget _body(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
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
                  _downloadSettingsSection(context, controller, state),
                  _xhttpSection(context, controller, state),
                  _securitySection(context, controller, state),
                  _securitySettings(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _headersSection(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
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

  Widget _xPaddingBytesSection(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
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

  Widget _xPaddingBytes(BuildContext context, XhttpDownloadSettingsController controller) {
    return TextField(
      controller: controller.xPaddingBytesController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageXPaddingBytes),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageXPaddingBytes,
      ),
    );
  }

  Widget _noGRPCHeader(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundXhttpPageNoGRPCHeader),
        Switch(
          value: state.downloadState.noGRPCHeader,
          onChanged: (value) => controller.updateNoGRPCHeader(value),
        ),
      ],
    );
  }

  Widget _scMaxEachPostBytes(BuildContext context, XhttpDownloadSettingsController controller) {
    return TextField(
      controller: controller.scMaxEachPostBytesController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageScMaxEachPostBytes),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageScMaxEachPostBytes,
      ),
    );
  }

  Widget _scMinPostsIntervalMs(BuildContext context, XhttpDownloadSettingsController controller) {
    return TextField(
      controller: controller.scMinPostsIntervalMsController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundXhttpPageScMinPostsIntervalMs),
        hintText: AppLocalizations.of(context)!.outboundXhttpPageScMinPostsIntervalMs,
      ),
    );
  }

  Widget _xmuxSection(BuildContext context, XhttpDownloadSettingsController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundXhttpPageXmux,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: controller.maxConcurrencyController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConcurrency), hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConcurrency)),
          TextField(controller: controller.maxConnectionsController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConnections), hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxMaxConnections)),
          TextField(controller: controller.cMaxReuseTimesController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxCMaxReuseTimes), hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxCMaxReuseTimes)),
          TextField(controller: controller.hMaxReusableSecsController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxReusableSecs), hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxReusableSecs)),
          TextField(controller: controller.hMaxRequestTimesController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxRequestTimes), hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxHMaxRequestTimes)),
          TextField(controller: controller.hKeepAlivePeriodController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundXhttpPageXmuxHKeepAlivePeriod), hintText: AppLocalizations.of(context)!.outboundXhttpPageXmuxHKeepAlivePeriod)),
        ],
      ),
    );
  }

  Widget _downloadSettingsSection(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
    return SectionView(
      title: "",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: controller.addressController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageAddress), hintText: AppLocalizations.of(context)!.outboundUIPageAddressExample)),
          TextField(controller: controller.portController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPagePort), hintText: AppLocalizations.of(context)!.outboundUIPagePortExample)),
          TextRow(title: AppLocalizations.of(context)!.outboundUIPageNetwork, detail: state.downloadState.network.name),
        ],
      ),
    );
  }

  Widget _xhttpSection(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageXhttpSettings,
      child: Column(
        children: [
          TextField(controller: controller.xhttpHostController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageHost), hintText: AppLocalizations.of(context)!.outboundUIPageHostExample)),
          TextField(controller: controller.xhttpPathController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPagePath), hintText: AppLocalizations.of(context)!.outboundUIPagePathExample)),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.outboundUIPageXhttpMode),
                TextMenuPicker(title: state.downloadState.xhttpMode.name, selections: XhttpMode.values, callback: (value) => controller.updateXhttpMode(value)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _securitySection(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageSecurity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(AppLocalizations.of(context)!.outboundUIPageSecurity),
          TextMenuPicker(title: state.downloadState.security.name, selections: StreamSettingsSecurity.xhttpDownloadSettingsSecurity, callback: (value) => controller.updateSecurity(value)),
        ],
      ),
    );
  }

  Widget _securitySettings(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
    switch (state.downloadState.security) {
      case StreamSettingsSecurity.tls:
        return _tlsSection(context, controller, state);
      case StreamSettingsSecurity.reality:
        return _realitySection(context, controller, state);
      case StreamSettingsSecurity.none:
        return Container();
    }
  }

  Widget _tlsSection(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
    final children = StreamSettingsSecurityALPN.values.map((value) {
      return FilterChip(label: Text(value.name), selected: state.downloadState.alpn.contains(value), onSelected: (bool selected) => controller.updateAlpn(selected, value));
    }).toList();
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageTlsSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: controller.serverNameController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageServerName), hintText: AppLocalizations.of(context)!.outboundUIPageServerNameExample)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLocalizations.of(context)!.outboundUIPageAlpn), Wrap(spacing: 5.0, runSpacing: 5.0, children: children)]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppLocalizations.of(context)!.outboundUIPageFingerprint), TextMenuPicker(title: state.downloadState.fingerprint.name, selections: StreamSettingsSecurityFingerprint.values, callback: (value) => controller.updateFingerprint(value))]),
          TextField(controller: controller.pinnedPeerCertSha256Controller, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPagePinnedPeerCertSha256), hintText: AppLocalizations.of(context)!.outboundUIPagePinnedPeerCertSha256)),
          TextField(controller: controller.verifyPeerCertByNameController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageVerifyPeerCertByName), hintText: AppLocalizations.of(context)!.outboundUIPageVerifyPeerCertByName)),
          TextField(controller: controller.echConfigListController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageEchConfigList), hintText: AppLocalizations.of(context)!.outboundUIPageEchConfigList)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppLocalizations.of(context)!.outboundUIPageEchForceQuery), TextMenuPicker(title: state.downloadState.echForceQuery.name, selections: StreamSettingsEchForceQuery.values, callback: (value) => controller.updateEchForceQuery(value))]),
        ],
      ),
    );
  }

  Widget _realitySection(BuildContext context, XhttpDownloadSettingsController controller, XhttpDownloadSettingsState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageRealitySettings,
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppLocalizations.of(context)!.outboundUIPageFingerprint), TextMenuPicker(title: state.downloadState.fingerprint.name, selections: StreamSettingsSecurityFingerprint.values, callback: (value) => controller.updateFingerprint(value))]),
          TextField(controller: controller.serverNameController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageServerName), hintText: AppLocalizations.of(context)!.outboundUIPageServerNameExample)),
          TextField(controller: controller.passwordController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPagePassword), hintText: AppLocalizations.of(context)!.outboundUIPagePassword)),
          TextField(controller: controller.shortIdController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageShortId), hintText: AppLocalizations.of(context)!.outboundUIPageShortId)),
          TextField(controller: controller.mldsa65VerifyController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageMldsa65Verify), hintText: AppLocalizations.of(context)!.outboundUIPageMldsa65Verify)),
          TextField(controller: controller.spiderXController, decoration: InputDecoration(label: Text(AppLocalizations.of(context)!.outboundUIPageSpiderX), hintText: AppLocalizations.of(context)!.outboundUIPageSpiderX)),
        ],
      ),
    );
  }

  Widget _bottomButton(BuildContext context, XhttpDownloadSettingsController controller) {
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
