import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/outbound/controller.dart';
import 'package:onexray/pages/home/xray/outbound/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/xray/outbound/enum.dart';

part 'advanced_section.dart';
part 'security_section.dart';

class OutboundUIPage extends StatelessWidget
    with OutboundSecuritySection, OutboundAdvancedSection {
  final OutboundUIParams params;

  const OutboundUIPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundUIController(params),
      child: BlocBuilder<OutboundUIController, OutboundUIState>(
        builder: (context, state) {
          final controller = context.read<OutboundUIController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.outboundPageTitle),
              actions: [
                IconButton(
                  onPressed: () => controller.gotoRawEdit(context),
                  icon: Icon(Icons.edit),
                ),
              ],
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _nameSection(context, controller),
                  _protocolSection(context, controller, state),
                  _settingsSection(context, controller, state),
                  _tagSection(context, controller, state),
                  _networkSection(context, controller, state),
                  _networkSettings(context, controller, state),
                  _finalMaskSection(context, controller),
                  _securitySection(context, controller, state),
                  _securitySettings(context, controller, state),
                  _sockoptSection(context, controller, state),
                  _muxSection(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _nameSection(BuildContext context, OutboundUIController controller) {
    return SettingSection(title: "", children: [_name(context, controller)]);
  }

  Widget _name(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.outboundUIPageName,
      hintText: AppLocalizations.of(context)!.outboundUIPageName,
    );
  }

  Widget _protocolSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: "",
      children: [_protocol(context, controller, state)],
    );
  }

  Widget _protocol(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageProtocol,
      value: state.outboundState.protocol.name,
      selections: XrayOutboundProtocol.outbounds,
      onSelected: (value) => controller.updateProtocol(value),
    );
  }

  Widget _settingsSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    switch (state.outboundState.protocol) {
      case XrayOutboundProtocol.vless:
        return _vlessSection(context, controller);
      case XrayOutboundProtocol.vmess:
        return _vmessSection(context, controller, state);
      case XrayOutboundProtocol.shadowsocks:
        return _shadowsocksSection(context, controller, state);
      case XrayOutboundProtocol.trojan:
        return _trojanSection(context, controller);
      case XrayOutboundProtocol.socks:
        return _socksSection(context, controller);
      case XrayOutboundProtocol.hysteria:
        return _hysteriaSection(context, controller, state);
      default:
        return Container();
    }
  }

  Widget _address(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.addressController,
      label: AppLocalizations.of(context)!.outboundUIPageAddress,
      hintText: AppLocalizations.of(context)!.outboundUIPageAddressExample,
    );
  }

  Widget _port(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.portController,
      label: AppLocalizations.of(context)!.outboundUIPagePort,
      hintText: AppLocalizations.of(context)!.outboundUIPagePortExample,
    );
  }

  Widget _vlessSection(BuildContext context, OutboundUIController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageVLESS,
      children: [
        _address(context, controller),
        _port(context, controller),
        _vlessId(context, controller),
        _vlessEncryption(context, controller),
        _vlessFlow(context, controller),
        _vlessReverse(context, controller),
      ],
    );
  }

  Widget _vlessId(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.vlessIdController,
      label: AppLocalizations.of(context)!.outboundUIPageId,
      hintText: AppLocalizations.of(context)!.outboundUIPageIdExample,
    );
  }

  Widget _vlessEncryption(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.vlessEncryptionController,
      label: AppLocalizations.of(context)!.outboundUIPageEncryption,
      hintText: AppLocalizations.of(context)!.outboundUIPageEncryption,
    );
  }

  Widget _vlessFlow(BuildContext context, OutboundUIController controller) {
    final state = context.read<OutboundUIController>().state;
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageFlow,
      value: state.outboundState.vlessFlow.name,
      selections: VLESSFlow.values,
      onSelected: (value) => controller.updateVlessFlow(value),
    );
  }

  Widget _vlessReverse(BuildContext context, OutboundUIController controller) {
    return SettingSubsection(
      title: AppLocalizations.of(context)!.outboundUIPageReverse,
      children: [_vlessReverseTag(context, controller)],
    );
  }

  Widget _vlessReverseTag(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.vlessReverseTagController,
      label: AppLocalizations.of(context)!.outboundUIPageTag,
      hintText: AppLocalizations.of(context)!.outboundUIPageTag,
    );
  }

  Widget _vmessSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageVMess,
      children: [
        _address(context, controller),
        _port(context, controller),
        _vmessId(context, controller),
        _vmessSecurity(context, controller, state),
      ],
    );
  }

  Widget _vmessId(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.vmessIdController,
      label: AppLocalizations.of(context)!.outboundUIPageId,
      hintText: AppLocalizations.of(context)!.outboundUIPageIdExample,
    );
  }

  Widget _vmessSecurity(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageVmessSecurity,
      value: state.outboundState.vmessSecurity.name,
      selections: VMessSecurity.values,
      onSelected: (value) => controller.updateVmessSecurity(value),
    );
  }

  Widget _shadowsocksSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageShadowsocks,
      children: [
        _address(context, controller),
        _port(context, controller),
        _shadowsocksMethod(context, controller, state),
        _shadowsocksPassword(context, controller),
        _shadowsocksUot(context, controller, state),
        _shadowsocksUoTVersion(context, controller, state),
      ],
    );
  }

  Widget _shadowsocksMethod(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageMethod,
      value: state.outboundState.shadowsocksMethod.name,
      selections: ShadowsocksMethod.values,
      onSelected: (value) => controller.updateShadowsocksMethod(value),
    );
  }

  Widget _shadowsocksPassword(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.shadowsocksPasswordController,
      label: AppLocalizations.of(context)!.outboundUIPagePassword,
      hintText: AppLocalizations.of(context)!.outboundUIPagePassword,
    );
  }

  Widget _shadowsocksUot(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageUot,
      value: state.outboundState.shadowsocksUot,
      onChanged: (value) => controller.updateShadowsocksUot(value),
    );
  }

  Widget _shadowsocksUoTVersion(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageUoTVersion,
      value: state.outboundState.shadowsocksUotVersion.name,
      selections: ShadowsocksUoTVersion.values,
      onSelected: (value) => controller.updateShadowsocksUotVersion(value),
    );
  }

  Widget _trojanSection(BuildContext context, OutboundUIController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageTrojan,
      children: [
        _address(context, controller),
        _port(context, controller),
        _trojanPassword(context, controller),
      ],
    );
  }

  Widget _trojanPassword(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.trojanPasswordController,
      label: AppLocalizations.of(context)!.outboundUIPagePassword,
      hintText: AppLocalizations.of(context)!.outboundUIPagePassword,
    );
  }

  Widget _socksSection(BuildContext context, OutboundUIController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageSocks,
      children: [
        _address(context, controller),
        _port(context, controller),
        _socksUser(context, controller),
        _socksPass(context, controller),
      ],
    );
  }

  Widget _socksUser(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.socksUserController,
      label: AppLocalizations.of(context)!.outboundUIPageUser,
      hintText: AppLocalizations.of(context)!.outboundUIPageUser,
    );
  }

  Widget _socksPass(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.socksPassController,
      label: AppLocalizations.of(context)!.outboundUIPagePass,
      hintText: AppLocalizations.of(context)!.outboundUIPagePass,
    );
  }

  Widget _hysteriaSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageHysteria,
      children: [
        _hysteriaVersion(context, controller, state),
        _address(context, controller),
        _port(context, controller),
      ],
    );
  }

  Widget _tagSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: "",
      children: [_tag(context, controller, state)],
    );
  }

  Widget _tag(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageTag,
      value: state.outboundState.tag,
    );
  }

  Widget _networkSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: "",
      children: [_network(context, controller, state)],
    );
  }

  Widget _network(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageNetwork,
      value: state.outboundState.network.name,
      selections: StreamSettingsNetwork.values,
      onSelected: (value) => controller.updateNetwork(value),
    );
  }

  Widget _networkSettings(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    switch (state.outboundState.network) {
      case StreamSettingsNetwork.raw:
        return _rawSection(context, controller, state);
      case StreamSettingsNetwork.xhttp:
        return _xhttpSection(context, controller, state);
      case StreamSettingsNetwork.kcp:
        return _kcpSection(context, controller, state);
      case StreamSettingsNetwork.grpc:
        return _grpcSection(context, controller, state);
      case StreamSettingsNetwork.ws:
        return _wsSection(context, controller);
      case StreamSettingsNetwork.httpupgrade:
        return _httpupgradeSection(context, controller);
      case StreamSettingsNetwork.hysteria:
        return _streamHysteriaSection(context, controller, state);
    }
  }

  Widget _rawSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageRawSettings,
      separated: false,
      children: [_rawHeaderSection(context, controller, state)],
    );
  }

  Widget _rawHeaderSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSubsection(
      title: AppLocalizations.of(context)!.outboundUIPageRawHeader,
      children: [
        _rawHeaderType(context, controller, state),
        if (state.outboundState.rawHeaderType == RawHeaderType.http)
          _rawHeader(context, controller, state),
      ],
    );
  }

  Widget _rawHeaderType(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageRawHeaderType,
      value: state.outboundState.rawHeaderType.name,
      selections: RawHeaderType.values,
      onSelected: (value) => controller.updateRawHeaderType(value),
    );
  }

  Widget _rawHeader(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    final pathTitle = AppLocalizations.of(context)!.outboundUIPagePath;
    final hostTitle = AppLocalizations.of(context)!.outboundUIPageHost;
    final rawPathViews = state.outboundState.rawPath
        .mapIndexed(
          (index, path) => TextFieldActionSettingRow(
            controller: controller.rawPathControllers[index],
            label: pathTitle,
            hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
            trailing: IconButton(
              onPressed: () => controller.deleteRawPath(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();

    final rawHostViews = state.outboundState.rawHost
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.rawHostControllers[index],
            label: hostTitle,
            hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
            trailing: IconButton(
              onPressed: () => controller.deleteRawHost(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: pathTitle,
          trailing: IconButton(
            onPressed: () => controller.appendRawPath(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...rawPathViews,
        SettingRow(
          title: hostTitle,
          trailing: IconButton(
            onPressed: () => controller.appendRawHost(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...rawHostViews,
      ],
    );
  }

  Widget _xhttpSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageXhttpSettings,
      children: [
        _xhttpHost(context, controller),
        _xhttpPath(context, controller),
        _xhttpMode(context, controller, state),
        _xhttpExtra(context, controller),
      ],
    );
  }

  Widget _xhttpHost(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.xhttpHostController,
      label: AppLocalizations.of(context)!.outboundUIPageHost,
      hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
    );
  }

  Widget _xhttpPath(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.xhttpPathController,
      label: AppLocalizations.of(context)!.outboundUIPagePath,
      hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
    );
  }

  Widget _xhttpMode(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageXhttpMode,
      value: state.outboundState.xhttpMode.name,
      selections: XhttpMode.values,
      onSelected: (value) => controller.updateXhttpMode(value),
    );
  }

  Widget _xhttpExtra(BuildContext context, OutboundUIController controller) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageXhttpExtra,
      onTap: () => controller.editXhttpExtra(context),
    );
  }

  Widget _kcpSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageKcpSettings,
      children: [
        _kcpHeaderSection(context, controller, state),
        _kcpSeed(context, controller),
      ],
    );
  }

  Widget _kcpHeaderSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSubsection(
      title: AppLocalizations.of(context)!.outboundUIPageKcpHeader,
      children: [
        _kcpHeaderType(context, controller, state),
        _kcpHeaderDomain(context, controller),
      ],
    );
  }

  Widget _kcpHeaderType(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageKcpHeaderType,
      value: state.outboundState.kcpHeaderType.name,
      selections: KcpHeaderType.values,
      onSelected: (value) => controller.updateKcpHeaderType(value),
    );
  }

  Widget _kcpHeaderDomain(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.kcpHeaderDomainController,
      label: AppLocalizations.of(context)!.outboundUIPageKcpHeaderDomain,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPageKcpHeaderDomainExample,
    );
  }

  Widget _kcpSeed(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.kcpSeedController,
      label: AppLocalizations.of(context)!.outboundUIPageKcpSeed,
      hintText: AppLocalizations.of(context)!.outboundUIPageKcpSeed,
    );
  }

  Widget _grpcSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageGrpcSettings,
      children: [
        _grpcAuthority(context, controller),
        _grpcServiceName(context, controller),
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.outboundUIPageGrpcMultiMode,
          value: state.outboundState.grpcMultiMode,
          onChanged: (value) => controller.updateGrpcMultiMode(value),
        ),
      ],
    );
  }

  Widget _grpcAuthority(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.grpcAuthorityController,
      label: AppLocalizations.of(context)!.outboundUIPageGrpcAuthority,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPageGrpcAuthorityExample,
    );
  }

  Widget _grpcServiceName(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.grpcServiceNameController,
      label: AppLocalizations.of(context)!.outboundUIPageGrpcServiceName,
      hintText: AppLocalizations.of(context)!.outboundUIPageGrpcServiceName,
    );
  }

  Widget _wsSection(BuildContext context, OutboundUIController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageWsSettings,
      children: [_wsPath(context, controller), _wsHost(context, controller)],
    );
  }

  Widget _wsPath(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.wsPathController,
      label: AppLocalizations.of(context)!.outboundUIPagePath,
      hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
    );
  }

  Widget _wsHost(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.wsHostController,
      label: AppLocalizations.of(context)!.outboundUIPageHost,
      hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
    );
  }

  Widget _httpupgradeSection(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageHttpupgradeSettings,
      children: [
        _httpupgradeHost(context, controller),
        _httpupgradePath(context, controller),
      ],
    );
  }

  Widget _httpupgradeHost(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.httpupgradeHostController,
      label: AppLocalizations.of(context)!.outboundUIPageHost,
      hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
    );
  }

  Widget _httpupgradePath(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.httpupgradePathController,
      label: AppLocalizations.of(context)!.outboundUIPagePath,
      hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
    );
  }

  Widget _streamHysteriaSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageHysteriaSettings,
      children: [
        _hysteriaVersion(context, controller, state),
        _hysteriaAuth(context, controller),
        _hysteriaUp(context, controller),
        _hysteriaDown(context, controller),
        _hysteriaUdphopSection(context, controller),
      ],
    );
  }

  Widget _hysteriaVersion(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageHysteriaVersion,
      value: state.outboundState.hysteriaVersion,
    );
  }

  Widget _hysteriaAuth(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.hysteriaAuthController,
      label: AppLocalizations.of(context)!.outboundUIPageHysteriaAuth,
      hintText: AppLocalizations.of(context)!.outboundUIPageHysteriaAuth,
    );
  }

  Widget _hysteriaUp(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.hysteriaUpController,
      label: AppLocalizations.of(context)!.outboundUIPageHysteriaUp,
      hintText: AppLocalizations.of(context)!.outboundUIPageHysteriaUp,
    );
  }

  Widget _hysteriaDown(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.hysteriaDownController,
      label: AppLocalizations.of(context)!.outboundUIPageHysteriaDown,
      hintText: AppLocalizations.of(context)!.outboundUIPageHysteriaDown,
    );
  }

  Widget _hysteriaUdphopSection(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return SettingSubsection(
      title: AppLocalizations.of(context)!.outboundUIPageHysteriaUdphop,
      children: [
        _hysteriaUdphopPort(context, controller),
        _hysteriaUdphopInterval(context, controller),
      ],
    );
  }

  Widget _hysteriaUdphopPort(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.hysteriaUdphopPortController,
      label: AppLocalizations.of(context)!.outboundUIPageHysteriaUdphopPort,
      hintText: AppLocalizations.of(context)!.outboundUIPageHysteriaUdphopPort,
    );
  }

  Widget _hysteriaUdphopInterval(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.hysteriaUdphopIntervalController,
      label: AppLocalizations.of(context)!.outboundUIPageHysteriaUdphopInterval,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPageHysteriaUdphopInterval,
    );
  }
}
