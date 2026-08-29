import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/outbound/controller.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

part 'security_section.dart';

class OutboundUIPage extends StatelessWidget with OutboundSecuritySection {
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
                tooltip: AppLocalizations.of(context)!.xrayRawPageTitle,
                onPressed: () => controller.gotoRawEdit(context),
                icon: const Icon(LucideIcons.braces),
              ),
              BlocBuilder<AppEventBus, AppEventBusState>(
                bloc: AppEventBus.instance,
                builder: (context, eventState) {
                  return IconButton(
                    tooltip: AppLocalizations.of(context)!.outboundPageRealPing,
                    onPressed: eventState.pinging
                        ? null
                        : () => controller.realPing(context),
                    icon: eventState.pinging
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.gauge),
                  );
                },
              ),
            ],
            body: IgnorePointer(
              ignoring: !state.loaded,
              child: _body(context, controller, state),
            ),
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
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      desktopMaxWidth: 1080,
      child: Column(
        children: [
          SettingSection(
            title: '',
            description: l10n.outboundUIPageRawJsonHint,
            children: [
              _tag(context, controller, state),
              _protocol(context, controller, state),
              ..._protocolFields(context, controller, state),
            ],
          ),
          SettingSection(
            title: l10n.outboundUIPageNetwork,
            children: [
              _network(context, controller, state),
              ..._networkFields(context, controller, state),
            ],
          ),
          SettingSection(
            title: l10n.outboundUIPageSecurity,
            children: [
              _security(context, controller, state),
              ..._securityFields(context, controller, state),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    final title = AppLocalizations.of(context)!.outboundUIPageTag;
    if (params.fixedTag.isEmpty) {
      return TextFieldSettingRow(
        controller: controller.tagController,
        label: title,
        hintText: title,
      );
    }
    return SettingRow(title: title, value: state.outboundState.tag);
  }

  Widget _protocol(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final protocol = state.outboundState.protocol;
    return SelectSettingRow(
      title: localizations.outboundUIPageProtocol,
      value: state.outboundState.protocolName,
      displayValue: protocol == null
          ? null
          : _protocolTitle(localizations, protocol),
      selections: outboundProtocols,
      titleBuilder: (value) => _protocolTitle(localizations, value),
      onSelected: controller.updateProtocol,
    );
  }

  String _protocolTitle(
    AppLocalizations localizations,
    XrayOutboundProtocol protocol,
  ) => switch (protocol) {
    XrayOutboundProtocol.vless => localizations.outboundUIPageVLESS,
    XrayOutboundProtocol.vmess => localizations.outboundUIPageVMess,
    XrayOutboundProtocol.shadowsocks => localizations.outboundUIPageShadowsocks,
    XrayOutboundProtocol.trojan => localizations.outboundUIPageTrojan,
    XrayOutboundProtocol.socks => localizations.outboundUIPageSocks,
    XrayOutboundProtocol.hysteria => localizations.outboundUIPageHysteria,
    _ => protocol.name,
  };

  List<Widget> _protocolFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    final outbound = state.outboundState;
    if (!outbound.protocolFieldsProjectable) {
      return const [];
    }
    return switch (outbound.protocol) {
      XrayOutboundProtocol.vless => [
        _address(context, controller),
        _port(context, controller),
        _text(
          context,
          controller.vlessIdController,
          AppLocalizations.of(context)!.outboundUIPageId,
          hint: AppLocalizations.of(context)!.outboundUIPageIdExample,
        ),
        _text(
          context,
          controller.vlessEncryptionController,
          AppLocalizations.of(context)!.outboundUIPageEncryption,
        ),
        _text(
          context,
          controller.vlessFlowController,
          AppLocalizations.of(context)!.outboundUIPageFlow,
        ),
      ],
      XrayOutboundProtocol.vmess => [
        _address(context, controller),
        _port(context, controller),
        _text(
          context,
          controller.vmessIdController,
          AppLocalizations.of(context)!.outboundUIPageId,
          hint: AppLocalizations.of(context)!.outboundUIPageIdExample,
        ),
        SelectSettingRow(
          title: AppLocalizations.of(context)!.outboundUIPageVmessSecurity,
          value: outbound.vmessSecurityName,
          selections: VMessSecurity.values,
          onSelected: controller.updateVmessSecurity,
        ),
      ],
      XrayOutboundProtocol.shadowsocks => [
        _address(context, controller),
        _port(context, controller),
        SelectSettingRow(
          title: AppLocalizations.of(context)!.outboundUIPageMethod,
          value: outbound.shadowsocksMethodName,
          selections: ShadowsocksMethod.values,
          onSelected: controller.updateShadowsocksMethod,
        ),
        _text(
          context,
          controller.shadowsocksPasswordController,
          AppLocalizations.of(context)!.outboundUIPagePassword,
        ),
      ],
      XrayOutboundProtocol.trojan => [
        _address(context, controller),
        _port(context, controller),
        _text(
          context,
          controller.trojanPasswordController,
          AppLocalizations.of(context)!.outboundUIPagePassword,
        ),
      ],
      XrayOutboundProtocol.socks => [
        _address(context, controller),
        _port(context, controller),
        _text(
          context,
          controller.socksUserController,
          AppLocalizations.of(context)!.outboundUIPageUser,
        ),
        _text(
          context,
          controller.socksPassController,
          AppLocalizations.of(context)!.outboundUIPagePass,
        ),
      ],
      XrayOutboundProtocol.hysteria => [
        _address(context, controller),
        _port(context, controller),
        _text(
          context,
          controller.hysteriaAuthController,
          AppLocalizations.of(context)!.outboundUIPageHysteriaAuth,
        ),
      ],
      _ => const <Widget>[],
    };
  }

  Widget _address(BuildContext context, OutboundUIController controller) {
    return _text(
      context,
      controller.addressController,
      AppLocalizations.of(context)!.outboundUIPageAddress,
      hint: AppLocalizations.of(context)!.outboundUIPageAddressExample,
    );
  }

  Widget _port(BuildContext context, OutboundUIController controller) {
    return _text(
      context,
      controller.portController,
      AppLocalizations.of(context)!.outboundUIPagePort,
      hint: AppLocalizations.of(context)!.outboundUIPagePortExample,
    );
  }

  Widget _network(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    final outbound = state.outboundState;
    final title = AppLocalizations.of(context)!.outboundUIPageNetwork;
    if (outbound.isHysteria) {
      return SettingRow(title: title, value: outbound.networkName);
    }
    return SelectSettingRow(
      title: title,
      value: outbound.networkName,
      selections: outboundNetworks,
      onSelected: controller.updateNetwork,
    );
  }

  List<Widget> _networkFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    final outbound = state.outboundState;
    if (!outbound.networkFieldsProjectable) {
      return const [];
    }
    return switch (outbound.network) {
      StreamSettingsNetwork.ws => [
        _text(
          context,
          controller.wsHostController,
          AppLocalizations.of(context)!.outboundUIPageHost,
          hint: AppLocalizations.of(context)!.outboundUIPageHostExample,
        ),
        _text(
          context,
          controller.wsPathController,
          AppLocalizations.of(context)!.outboundUIPagePath,
          hint: AppLocalizations.of(context)!.outboundUIPagePathExample,
        ),
      ],
      StreamSettingsNetwork.grpc => [
        _text(
          context,
          controller.grpcAuthorityController,
          AppLocalizations.of(context)!.outboundUIPageGrpcAuthority,
          hint: AppLocalizations.of(context)!
              .outboundUIPageGrpcAuthorityExample,
        ),
        _text(
          context,
          controller.grpcServiceNameController,
          AppLocalizations.of(context)!.outboundUIPageGrpcServiceName,
        ),
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.outboundUIPageGrpcMultiMode,
          value: outbound.grpcMultiMode,
          onChanged: controller.updateGrpcMultiMode,
        ),
      ],
      StreamSettingsNetwork.httpupgrade => [
        _text(
          context,
          controller.httpupgradeHostController,
          AppLocalizations.of(context)!.outboundUIPageHost,
          hint: AppLocalizations.of(context)!.outboundUIPageHostExample,
        ),
        _text(
          context,
          controller.httpupgradePathController,
          AppLocalizations.of(context)!.outboundUIPagePath,
          hint: AppLocalizations.of(context)!.outboundUIPagePathExample,
        ),
      ],
      StreamSettingsNetwork.xhttp => [
        _text(
          context,
          controller.xhttpHostController,
          AppLocalizations.of(context)!.outboundUIPageHost,
          hint: AppLocalizations.of(context)!.outboundUIPageHostExample,
        ),
        _text(
          context,
          controller.xhttpPathController,
          AppLocalizations.of(context)!.outboundUIPagePath,
          hint: AppLocalizations.of(context)!.outboundUIPagePathExample,
        ),
        _text(
          context,
          controller.xhttpModeController,
          AppLocalizations.of(context)!.outboundUIPageXhttpMode,
        ),
      ],
      _ => const <Widget>[],
    };
  }

  Widget _text(
    BuildContext context,
    TextEditingController controller,
    String label, {
    String? hint,
  }) {
    return TextFieldSettingRow(
      controller: controller,
      label: label,
      hintText: hint ?? label,
    );
  }
}
