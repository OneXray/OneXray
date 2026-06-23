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
        _sockoptDomainStrategy(context, controller, state),
        _v6only(context, controller, state),
        _dialerProxy(context, controller, state),
        if (AppPlatform.isLinux || AppPlatform.isWindows)
          _interface(context, controller, state),
        _tcpMptcp(context, controller, state),
        _addressPortStrategy(context, controller, state),
        _happyEyeballsEnabled(context, controller, state),
        if (state.outboundState.happyEyeballsEnabled) ...[
          _happyEyeballsPrioritizeIPv6(context, controller, state),
          _happyEyeballsTryDelayMs(context, controller),
          _happyEyeballsInterleave(context, controller),
          _happyEyeballsMaxConcurrentTry(context, controller),
        ],
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

  Widget _sockoptDomainStrategy(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageDomainStrategy,
      value: state.outboundState.sockoptDomainStrategy.name,
      selections: XrayDomainStrategy.values,
      onSelected: (value) => controller.updateSockoptDomainStrategy(value),
    );
  }

  Widget _v6only(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageV6only,
      value: state.outboundState.v6only,
      onChanged: (value) => controller.updateV6only(value),
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

  Widget _addressPortStrategy(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageAddressPortStrategy,
      value: state.outboundState.addressPortStrategy.name,
      selections: AddressPortStrategy.values,
      onSelected: (value) => controller.updateAddressPortStrategy(value),
    );
  }

  Widget _happyEyeballsEnabled(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageHappyEyeballs,
      value: state.outboundState.happyEyeballsEnabled,
      onChanged: (value) => controller.updateHappyEyeballsEnabled(value),
    );
  }

  Widget _happyEyeballsPrioritizeIPv6(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPagePrioritizeIPv6,
      value: state.outboundState.happyEyeballsPrioritizeIPv6,
      onChanged: (value) => controller.updateHappyEyeballsPrioritizeIPv6(value),
    );
  }

  Widget _happyEyeballsTryDelayMs(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.happyEyeballsTryDelayMsController,
      label: AppLocalizations.of(context)!.outboundUIPageTryDelayMs,
      hintText: AppLocalizations.of(context)!.outboundUIPageTryDelayMsExample,
    );
  }

  Widget _happyEyeballsInterleave(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.happyEyeballsInterleaveController,
      label: AppLocalizations.of(context)!.outboundUIPageInterleave,
      hintText: AppLocalizations.of(context)!.outboundUIPageInterleaveExample,
    );
  }

  Widget _happyEyeballsMaxConcurrentTry(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.happyEyeballsMaxConcurrentTryController,
      label: AppLocalizations.of(context)!.outboundUIPageMaxConcurrentTry,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPageMaxConcurrentTryExample,
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
