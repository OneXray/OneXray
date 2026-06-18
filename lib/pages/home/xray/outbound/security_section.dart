part of 'page.dart';

mixin OutboundSecuritySection {
  Widget _finalMaskSection(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageFinalmask,
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.outboundUIPageFinalmask,
          onTap: () => controller.editFinalMask(context),
        ),
      ],
    );
  }

  Widget _securitySection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: "",
      children: [_security(context, controller, state)],
    );
  }

  Widget _security(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageSecurity,
      value: state.outboundState.security.name,
      selections: StreamSettingsSecurity.values,
      onSelected: (value) => controller.updateSecurity(value),
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
    return TextFieldSettingRow(
      controller: controller.serverNameController,
      label: AppLocalizations.of(context)!.outboundUIPageServerName,
      hintText: AppLocalizations.of(context)!.outboundUIPageServerNameExample,
    );
  }

  Widget _fingerprint(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageFingerprint,
      value: state.outboundState.fingerprint.name,
      selections: StreamSettingsSecurityFingerprint.values,
      onSelected: (value) => controller.updateFingerprint(value),
    );
  }

  Widget _tlsSection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageTlsSettings,
      children: [
        _serverName(context, controller),
        _alpn(context, controller, state),
        _fingerprint(context, controller, state),
        _pinnedPeerCertSha256(context, controller),
        _verifyPeerCertByName(context, controller),
        _echConfigList(context, controller),
        _echForceQuery(context, controller, state),
      ],
    );
  }

  Widget _alpn(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    final children = StreamSettingsSecurityALPN.values.map((value) {
      return FilterChip(
        label: Text(value.name),
        selected: state.outboundState.alpn.contains(value),
        onSelected: (bool selected) => controller.updateAlpn(selected, value),
      );
    }).toList();
    return SettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageAlpn,
      subtitleWidget: Wrap(spacing: 5.0, runSpacing: 5.0, children: children),
    );
  }

  Widget _pinnedPeerCertSha256(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.pinnedPeerCertSha256Controller,
      label: AppLocalizations.of(context)!.outboundUIPagePinnedPeerCertSha256,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPagePinnedPeerCertSha256,
    );
  }

  Widget _verifyPeerCertByName(
    BuildContext context,
    OutboundUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.verifyPeerCertByNameController,
      label: AppLocalizations.of(context)!.outboundUIPageVerifyPeerCertByName,
      hintText: AppLocalizations.of(
        context,
      )!.outboundUIPageVerifyPeerCertByName,
    );
  }

  Widget _echConfigList(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.echConfigListController,
      label: AppLocalizations.of(context)!.outboundUIPageEchConfigList,
      hintText: AppLocalizations.of(context)!.outboundUIPageEchConfigList,
    );
  }

  Widget _echForceQuery(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundUIPageEchForceQuery,
      value: state.outboundState.echForceQuery.name,
      selections: StreamSettingsEchForceQuery.values,
      onSelected: (value) => controller.updateEchForceQuery(value),
    );
  }

  Widget _realitySection(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundUIPageRealitySettings,
      children: [
        _fingerprint(context, controller, state),
        _serverName(context, controller),
        _password(context, controller),
        _shortId(context, controller),
        _mldsa65Verify(context, controller),
        _spiderX(context, controller),
      ],
    );
  }

  Widget _password(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.passwordController,
      label: AppLocalizations.of(context)!.outboundUIPagePassword,
      hintText: AppLocalizations.of(context)!.outboundUIPagePassword,
    );
  }

  Widget _shortId(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.shortIdController,
      label: AppLocalizations.of(context)!.outboundUIPageShortId,
      hintText: AppLocalizations.of(context)!.outboundUIPageShortId,
    );
  }

  Widget _mldsa65Verify(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.mldsa65VerifyController,
      label: AppLocalizations.of(context)!.outboundUIPageMldsa65Verify,
      hintText: AppLocalizations.of(context)!.outboundUIPageMldsa65Verify,
    );
  }

  Widget _spiderX(BuildContext context, OutboundUIController controller) {
    return TextFieldSettingRow(
      controller: controller.spiderXController,
      label: AppLocalizations.of(context)!.outboundUIPageSpiderX,
      hintText: AppLocalizations.of(context)!.outboundUIPageSpiderX,
    );
  }
}
