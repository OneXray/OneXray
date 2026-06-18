part of 'page.dart';

mixin OutboundAdvancedSection {
  Widget _sockoptSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageSockopt,
      children: [
        _tcpFastOpen(context, controller, state),
        _dialerProxy(context, controller, state),
        if (AppPlatform.isLinux || AppPlatform.isWindows)
          _interface(context, controller, state),
        _tcpMptcp(context, controller, state),
      ],
    );
  }

  Widget _tcpFastOpen(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageTcpFastOpen,
      value: state.outboundState.tcpFastOpen,
      onChanged: (value) => controller.updateTcpFastOpen(value),
    );
  }

  Widget _dialerProxy(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow<String>(
      title: AppLocalizations.of(context)!.outboundUIPageDialerProxy,
      value: state.outboundState.dialerProxy,
      selections: state.dialerProxies,
      onSelected: (value) => controller.updateDialerProxy(value),
    );
  }

  Widget _interface(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageInterface,
      value: state.outboundState.interface,
      onTap: () => controller.editInterface(context),
    );
  }

  Widget _tcpMptcp(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageTcpMptcp,
      value: state.outboundState.tcpMptcp,
      onChanged: (value) => controller.updateTcpMptcp(value),
    );
  }

  Widget _muxSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageMux,
      children: [
        _muxEnabled(context, controller, state),
        if (state.outboundState.muxEnabled) ...[
          _muxConcurrency(context, controller),
          _muxXudpConcurrency(context, controller),
          _muxXudpProxyUDP443(context, controller, state),
        ],
      ],
    );
  }

  Widget _muxEnabled(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.switchEnabled,
      value: state.outboundState.muxEnabled,
      onChanged: (value) => controller.updateMuxEnabled(value),
    );
  }

  Widget _muxXudpProxyUDP443(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageMuxXudpProxyUDP443,
      value: state.outboundState.muxXudpProxyUDP443.name,
      selections: MuxXudpProxyUDP443.values,
      onSelected: (value) => controller.updateMuxXudpProxyUDP443(value),
    );
  }

  Widget _muxConcurrency(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.muxConcurrencyController,
      label: AppLocalizations.of(context)!.outboundUIPageMuxConcurrency,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPageMuxConcurrencyExample,
    );
  }

  Widget _muxXudpConcurrency(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.muxXudpConcurrencyController,
      label: AppLocalizations.of(context)!.outboundUIPageMuxXudpConcurrency,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPageMuxXudpConcurrencyExample,
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
