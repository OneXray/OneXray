import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/outbound/controller.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      child: BlocBuilder<OutboundUIController, OutboundUIPageState>(
        builder: (context, state) {
          final controller = context.read<OutboundUIController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.outboundPageTitle,
            onSave: () => controller.save(context),
            actions: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.menuEdit,
                onPressed: () => controller.gotoRawEdit(context),
                icon: const Icon(LucideIcons.braces),
              ),
              BlocBuilder<AppEventBus, AppEventBusState>(
                bloc: AppEventBus.instance,
                builder: (context, eventState) {
                  final pinging = eventState.pinging;
                  return IconButton(
                    tooltip: AppLocalizations.of(context)!.outboundPageRealPing,
                    onPressed: pinging
                        ? null
                        : () => controller.realPing(context),
                    icon: pinging
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.gauge),
                  );
                },
              ),
            ],
            body: _body(context, controller, state),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return SettingsPageScroll(
      desktopMaxWidth: 1080,
      child: Column(
        children: [
          SettingSection(
            title: "",
            children: [
              _name(context, controller),
              _protocol(context, controller, state),
              ..._settingsFields(context, controller, state),
              _tag(context, controller, state),
            ],
          ),
          SettingSection(
            title: AppLocalizations.of(context)!.outboundUIPageNetwork,
            children: [
              _network(context, controller, state),
              ..._networkSettingsFields(context, controller, state),
              _finalMask(context, controller),
            ],
          ),
          SettingSection(
            title: AppLocalizations.of(context)!.outboundUIPageSecurity,
            children: [
              _security(context, controller, state),
              ..._securitySettingsFields(context, controller, state),
            ],
          ),
          _sockoptSection(context, controller, state),
          _muxSection(context, controller, state),
        ],
      ),
    );
  }

  Widget _name(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.outboundUIPageName,
      hintText: AppLocalizations.of(context)!.outboundUIPageName,
    );
  }

  Widget _protocol(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageProtocol,
      value: state.outboundState.protocol.name,
      selections: XrayOutboundProtocol.outbounds,
      onSelected: (value) => controller.updateProtocol(value),
    );
  }

  List<Widget> _settingsFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    switch (state.outboundState.protocol) {
      case XrayOutboundProtocol.vless:
        return _vlessFields(context, controller);
      case XrayOutboundProtocol.vmess:
        return _vmessFields(context, controller, state);
      case XrayOutboundProtocol.shadowsocks:
        return _shadowsocksFields(context, controller, state);
      case XrayOutboundProtocol.trojan:
        return _trojanFields(context, controller);
      case XrayOutboundProtocol.socks:
        return _socksFields(context, controller);
      case XrayOutboundProtocol.http:
        return _httpFields(context, controller);
      case XrayOutboundProtocol.hysteria:
        return _hysteriaFields(context, controller, state);
      default:
        return const [];
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

  List<Widget> _vlessFields(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return [
      _address(context, controller),
      _port(context, controller),
      _vlessId(context, controller),
      _vlessEncryption(context, controller),
      _vlessFlow(context, controller),
      _vlessReverse(context, controller),
    ];
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

  List<Widget> _vmessFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return [
      _address(context, controller),
      _port(context, controller),
      _vmessId(context, controller),
      _vmessSecurity(context, controller, state),
    ];
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
    OutboundUIPageState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageVmessSecurity,
      value: state.outboundState.vmessSecurity.name,
      selections: VMessSecurity.values,
      onSelected: (value) => controller.updateVmessSecurity(value),
    );
  }

  List<Widget> _shadowsocksFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return [
      _address(context, controller),
      _port(context, controller),
      _shadowsocksMethod(context, controller, state),
      _shadowsocksPassword(context, controller),
    ];
  }

  Widget _shadowsocksMethod(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
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

  List<Widget> _trojanFields(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return [
      _address(context, controller),
      _port(context, controller),
      _trojanPassword(context, controller),
    ];
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

  List<Widget> _socksFields(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return [
      _address(context, controller),
      _port(context, controller),
      _socksUser(context, controller),
      _socksPass(context, controller),
    ];
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

  List<Widget> _httpFields(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return [
      _address(context, controller),
      _port(context, controller),
      _httpUser(context, controller),
      _httpPass(context, controller),
      _httpHeaders(context, controller),
    ];
  }

  Widget _httpUser(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.httpUserController,
      label: AppLocalizations.of(context)!.outboundUIPageUser,
      hintText: AppLocalizations.of(context)!.outboundUIPageUser,
    );
  }

  Widget _httpPass(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.httpPassController,
      label: AppLocalizations.of(context)!.outboundUIPagePass,
      hintText: AppLocalizations.of(context)!.outboundUIPagePass,
    );
  }

  Widget _httpHeaders(BuildContext context, OutboundUIController controller) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageHeaders,
      onTap: () => controller.editHttpHeaders(context),
    );
  }

  List<Widget> _hysteriaFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return [
      _hysteriaVersion(context, controller, state),
      _address(context, controller),
      _port(context, controller),
    ];
  }

  Widget _tag(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    if (params.editableTag && params.fixedTag.isEmpty) {
      return TextFieldSettingRow(
        controller: controller.tagController,
        label: AppLocalizations.of(context)!.outboundUIPageTag,
        hintText: AppLocalizations.of(context)!.outboundUIPageTag,
      );
    }
    return SettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageTag,
      value: state.outboundState.tag,
    );
  }

  Widget _network(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageNetwork,
      value: state.outboundState.network.name,
      selections: StreamSettingsNetwork.values,
      onSelected: (value) => controller.updateNetwork(value),
    );
  }

  List<Widget> _networkSettingsFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    switch (state.outboundState.network) {
      case StreamSettingsNetwork.raw:
        return _rawFields(context, controller, state);
      case StreamSettingsNetwork.xhttp:
        return _xhttpFields(context, controller, state);
      case StreamSettingsNetwork.kcp:
        return const [];
      case StreamSettingsNetwork.grpc:
        return _grpcFields(context, controller, state);
      case StreamSettingsNetwork.ws:
        return _wsFields(context, controller);
      case StreamSettingsNetwork.httpupgrade:
        return _httpupgradeFields(context, controller);
      case StreamSettingsNetwork.hysteria:
        return _streamHysteriaFields(context, controller, state);
    }
  }

  List<Widget> _rawFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return [
      _rawHeaderType(context, controller, state),
      if (state.outboundState.rawHeaderType == RawHeaderType.http)
        _rawHeader(context, controller, state),
    ];
  }

  Widget _rawHeaderType(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
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
    OutboundUIPageState state,
  ) {
    final pathTitle = AppLocalizations.of(context)!.outboundUIPagePath;
    final hostTitle = AppLocalizations.of(context)!.outboundUIPageHost;
    final rawPathViews = state.outboundState.rawPath
        .mapIndexed(
          (index, path) => TextFieldActionSettingRow(
            controller: controller.rawPathControllers[index],
            label: pathTitle,
            showLabel: false,
            hintText: AppLocalizations.of(context)!.outboundUIPagePathExample,
            trailing: IconButton(
              onPressed: () => controller.deleteRawPath(context, index),
              icon: const Icon(LucideIcons.trash2),
            ),
          ),
        )
        .toList();

    final rawHostViews = state.outboundState.rawHost
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.rawHostControllers[index],
            label: hostTitle,
            showLabel: false,
            hintText: AppLocalizations.of(context)!.outboundUIPageHostExample,
            trailing: IconButton(
              onPressed: () => controller.deleteRawHost(context, index),
              icon: const Icon(LucideIcons.trash2),
            ),
          ),
        )
        .toList();
    return SettingSubsection(
      title: AppLocalizations.of(context)!.outboundUIPageRawHeader,
      children: [
        SettingRow(
          title: pathTitle,
          trailing: IconButton(
            onPressed: () => controller.appendRawPath(),
            icon: const Icon(LucideIcons.plus),
          ),
        ),
        ...rawPathViews,
        SettingRow(
          title: hostTitle,
          trailing: IconButton(
            onPressed: () => controller.appendRawHost(),
            icon: const Icon(LucideIcons.plus),
          ),
        ),
        ...rawHostViews,
      ],
    );
  }

  List<Widget> _xhttpFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return [
      _xhttpHost(context, controller),
      _xhttpPath(context, controller),
      _xhttpMode(context, controller, state),
      _xhttpExtra(context, controller),
    ];
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
    OutboundUIPageState state,
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

  List<Widget> _grpcFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return [
      _grpcAuthority(context, controller),
      _grpcServiceName(context, controller),
      SwitchSettingRow(
        title: AppLocalizations.of(context)!.outboundUIPageGrpcMultiMode,
        value: state.outboundState.grpcMultiMode,
        onChanged: (value) => controller.updateGrpcMultiMode(value),
      ),
    ];
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

  List<Widget> _wsFields(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return [_wsPath(context, controller), _wsHost(context, controller)];
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

  List<Widget> _httpupgradeFields(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return [
      _httpupgradeHost(context, controller),
      _httpupgradePath(context, controller),
    ];
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

  List<Widget> _streamHysteriaFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    return [
      _hysteriaVersion(context, controller, state),
      _hysteriaAuth(context, controller),
    ];
  }

  Widget _hysteriaVersion(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
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
}
