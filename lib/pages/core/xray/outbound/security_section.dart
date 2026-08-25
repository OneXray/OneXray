part of 'page.dart';

mixin OutboundSecuritySection {
  Widget _security(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    final outbound = state.outboundState;
    final title = AppLocalizations.of(context)!.outboundUIPageSecurity;
    if (outbound.isHysteria) {
      return SettingRow(title: title, value: outbound.securityName);
    }
    return SelectSettingRow(
      title: title,
      value: outbound.securityName,
      selections: StreamSettingsSecurity.values,
      onSelected: controller.updateSecurity,
    );
  }

  List<Widget> _securityFields(
    BuildContext context,
    OutboundUIController controller,
    OutboundUIPageState state,
  ) {
    final outbound = state.outboundState;
    if (!outbound.securityFieldsProjectable) {
      return const [];
    }
    return switch (outbound.security) {
      StreamSettingsSecurity.tls => [
        _securityText(
          context,
          controller.serverNameController,
          AppLocalizations.of(context)!.outboundUIPageServerName,
          hint: AppLocalizations.of(context)!.outboundUIPageServerNameExample,
        ),
        _securityText(
          context,
          controller.alpnController,
          AppLocalizations.of(context)!.outboundUIPageAlpn,
        ),
        _securityText(
          context,
          controller.fingerprintController,
          AppLocalizations.of(context)!.outboundUIPageFingerprint,
        ),
        _securityText(
          context,
          controller.echConfigListController,
          AppLocalizations.of(context)!.outboundUIPageEchConfigList,
        ),
        _securityText(
          context,
          controller.pinnedPeerCertSha256Controller,
          AppLocalizations.of(context)!.outboundUIPagePinnedPeerCertSha256,
        ),
        _securityText(
          context,
          controller.verifyPeerCertByNameController,
          AppLocalizations.of(context)!.outboundUIPageVerifyPeerCertByName,
        ),
      ],
      StreamSettingsSecurity.reality => [
        _securityText(
          context,
          controller.serverNameController,
          AppLocalizations.of(context)!.outboundUIPageServerName,
          hint: AppLocalizations.of(context)!.outboundUIPageServerNameExample,
        ),
        _securityText(
          context,
          controller.fingerprintController,
          AppLocalizations.of(context)!.outboundUIPageFingerprint,
        ),
        _securityText(
          context,
          controller.realityPasswordController,
          AppLocalizations.of(context)!.outboundUIPagePassword,
        ),
        _securityText(
          context,
          controller.shortIdController,
          AppLocalizations.of(context)!.outboundUIPageShortId,
        ),
        _securityText(
          context,
          controller.mldsa65VerifyController,
          AppLocalizations.of(context)!.outboundUIPageMldsa65Verify,
        ),
        _securityText(
          context,
          controller.spiderXController,
          AppLocalizations.of(context)!.outboundUIPageSpiderX,
        ),
      ],
      _ => const <Widget>[],
    };
  }

  Widget _securityText(
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
