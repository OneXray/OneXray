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
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/xray/outbound/enum.dart';

class OutboundUIPage extends StatelessWidget {
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

  Widget _body(BuildContext context, OutboundUIController controller, OutboundUIState state) {
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
    return SectionView(title: "", child: _name(context, controller));
  }

  Widget _name(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.nameController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageName),
        hintText: AppLocalizations.of(context)!.outboundUIPageName,
      ),
    );
  }

  Widget _protocolSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(title: "", child: _protocol(context, controller, state));
  }

  Widget _protocol(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageProtocol),
        TextMenuPicker(
          title: state.outboundState.protocol.name,
          selections: XrayOutboundProtocol.outbounds,
          callback: (value) => controller.updateProtocol(value),
        ),
      ],
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
    return TextField(
      controller: controller.addressController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageAddress),
        hintText: AppLocalizations.of(context)!.outboundUIPageAddressExample,
      ),
    );
  }

  Widget _port(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.portController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePort),
        hintText: AppLocalizations.of(context)!.outboundUIPagePortExample,
      ),
    );
  }

  Widget _vlessSection(BuildContext context, OutboundUIController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageVLESS,
      child: Column(
        children: [
          _address(context, controller),
          _port(context, controller),
          _vlessId(context, controller),
          _vlessEncryption(context, controller),
          _vlessFlow(context, controller),
          _vlessReverse(context, controller),
        ],
      ),
    );
  }

  Widget _vlessId(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.vlessIdController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageId),
        hintText: AppLocalizations.of(context)!.outboundUIPageIdExample,
      ),
    );
  }

  Widget _vlessEncryption(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.vlessEncryptionController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageEncryption),
        hintText: AppLocalizations.of(context)!.outboundUIPageEncryption,
      ),
    );
  }

  Widget _vlessFlow(BuildContext context, OutboundUIController controller) {
    final state = context.read<OutboundUIController>().state;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageFlow),
        TextMenuPicker(
          title: state.outboundState.vlessFlow.name,
          selections: VLESSFlow.values,
          callback: (value) => controller.updateVlessFlow(value),
        ),
      ],
    );
  }

  Widget _vlessReverse(BuildContext context, OutboundUIController controller) {
    return SectionView(
      level: SectionLevel.second,
      title: AppLocalizations.of(context)!.outboundUIPageReverse,
      child: _vlessReverseTag(context, controller),
    );
  }

  Widget _vlessReverseTag(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.vlessReverseTagController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageTag),
        hintText: AppLocalizations.of(context)!.outboundUIPageTag,
      ),
    );
  }

  Widget _vmessSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageVMess,
      child: Column(
        children: [
          _address(context, controller),
          _port(context, controller),
          _vmessId(context, controller),
          _vmessSecurity(context, controller, state),
        ],
      ),
    );
  }

  Widget _vmessId(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.vmessIdController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageId),
        hintText: AppLocalizations.of(context)!.outboundUIPageIdExample,
      ),
    );
  }

  Widget _vmessSecurity(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageVmessSecurity),
        TextMenuPicker(
          title: state.outboundState.vmessSecurity.name,
          selections: VMessSecurity.values,
          callback: (value) => controller.updateVmessSecurity(value),
        ),
      ],
    );
  }

  Widget _shadowsocksSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageVMess,
      child: Column(
        children: [
          _address(context, controller),
          _port(context, controller),
          _shadowsocksMethod(context, controller, state),
          _shadowsocksPassword(context, controller),
          _shadowsocksUot(context, controller, state),
          _shadowsocksUoTVersion(context, controller, state),
        ],
      ),
    );
  }

  Widget _shadowsocksMethod(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageMethod),
        TextMenuPicker(
          title: state.outboundState.shadowsocksMethod.name,
          selections: ShadowsocksMethod.values,
          callback: (value) => controller.updateShadowsocksMethod(value),
        ),
      ],
    );
  }

  Widget _shadowsocksPassword(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.shadowsocksPasswordController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePassword),
        hintText: AppLocalizations.of(context)!.outboundUIPagePassword,
      ),
    );
  }

  Widget _shadowsocksUot(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageUot),
        Switch(
          value: state.outboundState.shadowsocksUot,
          onChanged: (value) => controller.updateShadowsocksUot(value),
        ),
      ],
    );
  }

  Widget _shadowsocksUoTVersion(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageUoTVersion),
        TextMenuPicker(
          title: state.outboundState.shadowsocksUotVersion.name,
          selections: ShadowsocksUoTVersion.values,
          callback: (value) => controller.updateShadowsocksUotVersion(value),
        ),
      ],
    );
  }

  Widget _trojanSection(BuildContext context, OutboundUIController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageTrojan,
      child: Column(
        children: [
          _address(context, controller),
          _port(context, controller),
          _trojanPassword(context, controller),
        ],
      ),
    );
  }

  Widget _trojanPassword(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.trojanPasswordController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePassword),
        hintText: AppLocalizations.of(context)!.outboundUIPagePassword,
      ),
    );
  }

  Widget _socksSection(BuildContext context, OutboundUIController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageSocks,
      child: Column(
        children: [
          _address(context, controller),
          _port(context, controller),
          _socksUser(context, controller),
          _socksPass(context, controller),
        ],
      ),
    );
  }

  Widget _socksUser(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.socksUserController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageUser),
        hintText: AppLocalizations.of(context)!.outboundUIPageUser,
      ),
    );
  }

  Widget _socksPass(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.socksPassController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePass),
        hintText: AppLocalizations.of(context)!.outboundUIPagePass,
      ),
    );
  }

  Widget _hysteriaSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageHysteria,
      child: Column(
        children: [
          _hysteriaVersion(context, controller, state),
          _address(context, controller),
          _port(context, controller),
        ],
      ),
    );
  }

  Widget _tagSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(title: "", child: _tag(context, controller, state));
  }

  Widget _tag(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return TextRow(
      title: AppLocalizations.of(context)!.outboundUIPageTag,
      detail: state.outboundState.tag,
    );
  }

  Widget _networkSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: "",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_network(context, controller, state)],
      ),
    );
  }

  Widget _network(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageNetwork),
        TextMenuPicker(
          title: state.outboundState.network.name,
          selections: StreamSettingsNetwork.values,
          callback: (value) => controller.updateNetwork(value),
        ),
      ],
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

  Widget _rawSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageRawSettings,
      child: _rawHeaderSection(context, controller, state),
    );
  }

  Widget _rawHeaderSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageRawHeader,
      level: SectionLevel.second,
      child: Column(
        children: [
          _rawHeaderType(context, controller, state),
          if (state.outboundState.rawHeaderType ==
              RawHeaderType.http)
            _rawHeader(context, controller, state),
        ],
      ),
    );
  }

  Widget _rawHeaderType(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageRawHeaderType),
        TextMenuPicker(
          title: state.outboundState.rawHeaderType.name,
          selections: RawHeaderType.values,
          callback: (value) => controller.updateRawHeaderType(value),
        ),
      ],
    );
  }

  Widget _rawHeader(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    final rawPathViews = state.outboundState.rawPath
        .mapIndexed(
          (index, path) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.rawPathControllers[index],
                  decoration: InputDecoration(
                    label: Text(
                      AppLocalizations.of(context)!.outboundUIPagePath,
                    ),
                    hintText: AppLocalizations.of(
                      context,
                    )!.outboundUIPagePathExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteRawPath(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();

    final rawHostViews = state.outboundState.rawHost
        .mapIndexed(
          (index, host) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.rawHostControllers[index],
                  decoration: InputDecoration(
                    label: Text(
                      AppLocalizations.of(context)!.outboundUIPageHost,
                    ),
                    hintText: AppLocalizations.of(
                      context,
                    )!.outboundUIPageHostExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteRawHost(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.outboundUIPagePath),
            IconButton(
              onPressed: () => controller.appendRawPath(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (rawPathViews.isNotEmpty) Column(children: rawPathViews),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.outboundUIPageHost),
            IconButton(
              onPressed: () => controller.appendRawHost(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (rawHostViews.isNotEmpty) Column(children: rawHostViews),
      ],
    );
  }

  Widget _xhttpSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageXhttpSettings,
      child: Column(
        children: [
          _xhttpHost(context, controller),
          _xhttpPath(context, controller),
          _xhttpMode(context, controller, state),
          _xhttpExtra(context, controller),
        ],
      ),
    );
  }

  Widget _xhttpHost(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.xhttpHostController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageHost),
        hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
      ),
    );
  }

  Widget _xhttpPath(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.xhttpPathController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePath),
        hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
      ),
    );
  }

  Widget _xhttpMode(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(AppLocalizations.of(context)!.outboundUIPageXhttpMode),
          TextMenuPicker(
            title: state.outboundState.xhttpMode.name,
            selections: XhttpMode.values,
            callback: (value) => controller.updateXhttpMode(value),
          ),
        ],
      ),
    );
  }

  Widget _xhttpExtra(BuildContext context, OutboundUIController controller) {
    return InkWell(
      onTap: () => controller.editXhttpExtra(context),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.outboundUIPageXhttpExtra),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _kcpSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageKcpSettings,
      child: Column(
        children: [
          _kcpHeaderSection(context, controller, state),
          _kcpSeed(context, controller),
        ],
      ),
    );
  }

  Widget _kcpHeaderSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageKcpHeader,
      level: SectionLevel.second,
      child: Column(
        children: [
          _kcpHeaderType(context, controller, state),
          _kcpHeaderDomain(context, controller),
        ],
      ),
    );
  }

  Widget _kcpHeaderType(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageKcpHeaderType),
        TextMenuPicker(
          title: state.outboundState.kcpHeaderType.name,
          selections: KcpHeaderType.values,
          callback: (value) => controller.updateKcpHeaderType(value),
        ),
      ],
    );
  }

  Widget _kcpHeaderDomain(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.kcpHeaderDomainController,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.outboundUIPageKcpHeaderDomain,
        ),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPageKcpHeaderDomainExample,
      ),
    );
  }

  Widget _kcpSeed(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.kcpSeedController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageKcpSeed),
        hintText: AppLocalizations.of(context)!.outboundUIPageKcpSeed,
      ),
    );
  }

  Widget _grpcSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageGrpcSettings,
      child: Column(
        children: [
          _grpcAuthority(context, controller),
          _grpcServiceName(context, controller),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.outboundUIPageGrpcMultiMode),
              Switch(
                value: state.outboundState.grpcMultiMode,
                onChanged: (value) => controller.updateGrpcMultiMode(value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _grpcAuthority(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.grpcAuthorityController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageGrpcAuthority),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPageGrpcAuthorityExample,
      ),
    );
  }

  Widget _grpcServiceName(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.grpcServiceNameController,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.outboundUIPageGrpcServiceName,
        ),
        hintText: AppLocalizations.of(context)!.outboundUIPageGrpcServiceName,
      ),
    );
  }

  Widget _wsSection(BuildContext context, OutboundUIController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageWsSettings,
      child: Column(
        children: [_wsPath(context, controller), _wsHost(context, controller)],
      ),
    );
  }

  Widget _wsPath(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.wsPathController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePath),
        hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
      ),
    );
  }

  Widget _wsHost(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.wsHostController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageHost),
        hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
      ),
    );
  }

  Widget _httpupgradeSection(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageHttpupgradeSettings,
      child: Column(
        children: [
          _httpupgradeHost(context, controller),
          _httpupgradePath(context, controller),
        ],
      ),
    );
  }

  Widget _httpupgradeHost(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.httpupgradeHostController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageHost),
        hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
      ),
    );
  }

  Widget _httpupgradePath(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.httpupgradePathController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePath),
        hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
      ),
    );
  }

  Widget _streamHysteriaSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageHysteriaSettings,
      child: Column(
        children: [
          _hysteriaVersion(context, controller, state),
          _hysteriaAuth(context, controller),
          _hysteriaUp(context, controller),
          _hysteriaDown(context, controller),
          _hysteriaUdphopSection(context, controller),
        ],
      ),
    );
  }

  Widget _hysteriaVersion(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return TextRow(
      title: AppLocalizations.of(context)!.outboundUIPageHysteriaVersion,
      detail: state.outboundState.hysteriaVersion,
    );
  }

  Widget _hysteriaAuth(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.hysteriaAuthController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageHysteriaAuth),
        hintText: AppLocalizations.of(context)!.outboundUIPageHysteriaAuth,
      ),
    );
  }

  Widget _hysteriaUp(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.hysteriaUpController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageHysteriaUp),
        hintText: AppLocalizations.of(context)!.outboundUIPageHysteriaUp,
      ),
    );
  }

  Widget _hysteriaDown(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.hysteriaDownController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageHysteriaDown),
        hintText: AppLocalizations.of(context)!.outboundUIPageHysteriaDown,
      ),
    );
  }

  Widget _hysteriaUdphopSection(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageHysteriaUdphop,
      level: SectionLevel.second,
      child: Column(
        children: [
          _hysteriaUdphopPort(context, controller),
          _hysteriaUdphopInterval(context, controller),
        ],
      ),
    );
  }

  Widget _hysteriaUdphopPort(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.hysteriaUdphopPortController,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.outboundUIPageHysteriaUdphopPort,
        ),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPageHysteriaUdphopPort,
      ),
    );
  }

  Widget _hysteriaUdphopInterval(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.hysteriaUdphopIntervalController,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.outboundUIPageHysteriaUdphopInterval,
        ),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPageHysteriaUdphopInterval,
      ),
    );
  }

  Widget _finalMaskSection(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageFinalmask,
      child: Column(
        children: [
          InkWell(
            onTap: () => controller.editFinalMask(context),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.outboundUIPageFinalmask),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securitySection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(title: "", child: _security(context, controller, state));
  }

  Widget _security(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageSecurity),
        TextMenuPicker(
          title: state.outboundState.security.name,
          selections: StreamSettingsSecurity.values,
          callback: (value) => controller.updateSecurity(value),
        ),
      ],
    );
  }

  Widget _securitySettings(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    switch (state.outboundState.security) {
      case StreamSettingsSecurity.tls:
        return _tlsSection(context, controller, state);
      case StreamSettingsSecurity.reality:
        return _realitySection(context, controller, state);
      case StreamSettingsSecurity.none:
        return Container();
    }
  }

  Widget _serverName(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.serverNameController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageServerName),
        hintText: AppLocalizations.of(context)!.outboundUIPageServerNameExample,
      ),
    );
  }

  Widget _fingerprint(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageFingerprint),
        TextMenuPicker(
          title: state.outboundState.fingerprint.name,
          selections: StreamSettingsSecurityFingerprint.values,
          callback: (value) => controller.updateFingerprint(value),
        ),
      ],
    );
  }

  Widget _tlsSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageTlsSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _serverName(context, controller),
          _alpn(context, controller, state),
          _fingerprint(context, controller, state),
          _pinnedPeerCertSha256(context, controller),
          _verifyPeerCertByName(context, controller),
          _echConfigList(context, controller),
          _echForceQuery(context, controller, state),
        ],
      ),
    );
  }

  Widget _alpn(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    final children = StreamSettingsSecurityALPN.values.map((value) {
      return FilterChip(
        label: Text(value.name),
        selected: state.outboundState.alpn.contains(value),
        onSelected: (bool selected) => controller.updateAlpn(selected, value),
      );
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageAlpn),
        Wrap(spacing: 5.0, runSpacing: 5.0, children: children),
      ],
    );
  }

  Widget _pinnedPeerCertSha256(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.pinnedPeerCertSha256Controller,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.outboundUIPagePinnedPeerCertSha256,
        ),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPagePinnedPeerCertSha256,
      ),
    );
  }

  Widget _verifyPeerCertByName(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.verifyPeerCertByNameController,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.outboundUIPageVerifyPeerCertByName,
        ),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPageVerifyPeerCertByName,
      ),
    );
  }

  Widget _echConfigList(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.echConfigListController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageEchConfigList),
        hintText: AppLocalizations.of(context)!.outboundUIPageEchConfigList,
      ),
    );
  }

  Widget _echForceQuery(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageEchForceQuery),
        TextMenuPicker(
          title: state.outboundState.echForceQuery.name,
          selections: StreamSettingsEchForceQuery.values,
          callback: (value) => controller.updateEchForceQuery(value),
        ),
      ],
    );
  }

  Widget _realitySection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageRealitySettings,
      child: Column(
        children: [
          _fingerprint(context, controller, state),
          _serverName(context, controller),
          _password(context, controller),
          _shortId(context, controller),
          _mldsa65Verify(context, controller),
          _spiderX(context, controller),
        ],
      ),
    );
  }

  Widget _password(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.passwordController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPagePassword),
        hintText: AppLocalizations.of(context)!.outboundUIPagePassword,
      ),
    );
  }

  Widget _shortId(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.shortIdController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageShortId),
        hintText: AppLocalizations.of(context)!.outboundUIPageShortId,
      ),
    );
  }

  Widget _mldsa65Verify(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.mldsa65VerifyController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageMldsa65Verify),
        hintText: AppLocalizations.of(context)!.outboundUIPageMldsa65Verify,
      ),
    );
  }

  Widget _spiderX(BuildContext context, OutboundUIController controller) {
    return TextField(
      controller: controller.spiderXController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageSpiderX),
        hintText: AppLocalizations.of(context)!.outboundUIPageSpiderX,
      ),
    );
  }

  Widget _sockoptSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageSockopt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tcpFastOpen(context, controller, state),
          _dialerProxy(context, controller, state),
          if (AppPlatform.isLinux || AppPlatform.isWindows)
            _interface(context, controller, state),
          _tcpMptcp(context, controller, state),
        ],
      ),
    );
  }

  Widget _tcpFastOpen(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageTcpFastOpen),
        Switch(
          value: state.outboundState.tcpFastOpen,
          onChanged: (value) => controller.updateTcpFastOpen(value),
        ),
      ],
    );
  }

  Widget _dialerProxy(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageDialerProxy),
        TextMenuPicker<String>(
          title: state.outboundState.dialerProxy,
          selections: state.dialerProxies,
          callback: (value) => controller.updateDialerProxy(value),
        ),
      ],
    );
  }

  Widget _interface(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return InkWell(
      onTap: () => controller.editInterface(context),
      child: TextRow(
        title: AppLocalizations.of(context)!.outboundUIPageInterface,
        detail: state.outboundState.interface,
      ),
    );
  }

  Widget _tcpMptcp(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundUIPageTcpMptcp),
        Switch(
          value: state.outboundState.tcpMptcp,
          onChanged: (value) => controller.updateTcpMptcp(value),
        ),
      ],
    );
  }

  Widget _muxSection(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundUIPageMux,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _muxEnabled(context, controller, state),
          if (state.outboundState.muxEnabled)
            _muxSectionBody(context, controller, state),
        ],
      ),
    );
  }

  Widget _muxEnabled(BuildContext context, OutboundUIController controller, OutboundUIState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.switchEnabled),
        Switch(
          value: state.outboundState.muxEnabled,
          onChanged: (value) => controller.updateMuxEnabled(value),
        ),
      ],
    );
  }

  Widget _muxSectionBody(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return Column(
      children: [
        _muxConcurrency(context, controller),
        _muxXudpConcurrency(context, controller),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.outboundUIPageMuxXudpProxyUDP443,
            ),
            TextMenuPicker(
              title: state.outboundState.muxXudpProxyUDP443.name,
              selections: MuxXudpProxyUDP443.values,
              callback: (value) => controller.updateMuxXudpProxyUDP443(value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _muxConcurrency(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.muxConcurrencyController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundUIPageMuxConcurrency),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPageMuxConcurrencyExample,
      ),
    );
  }

  Widget _muxXudpConcurrency(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextField(
      controller: controller.muxXudpConcurrencyController,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.outboundUIPageMuxXudpConcurrency,
        ),
        hintText: AppLocalizations.of(
          context,
        )!.outboundUIPageMuxXudpConcurrencyExample,
      ),
    );
  }

  Widget _bottomButton(BuildContext context, OutboundUIController controller) {
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
    OutboundUIController controller,
    AppEventBusState eventState,
  ) {
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
