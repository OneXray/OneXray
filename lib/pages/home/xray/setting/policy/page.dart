import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/policy/params.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class PolicyPage extends StatelessWidget {
  final PolicyParams params;

  const PolicyPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.policyPageTitle),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final system = params.state.system;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          child: SettingSection(
            title: AppLocalizations.of(context)!.policyPageSystem,
            children: [
              _boolRow(
                context,
                AppLocalizations.of(context)!.policyPageStatsInboundUplink,
                system.statsInboundUplink,
              ),
              _boolRow(
                context,
                AppLocalizations.of(context)!.policyPageStatsInboundDownlink,
                system.statsInboundDownlink,
              ),
              _boolRow(
                context,
                AppLocalizations.of(context)!.policyPageStatsOutboundUplink,
                system.statsOutboundUplink,
              ),
              _boolRow(
                context,
                AppLocalizations.of(context)!.policyPageStatsOutboundDownlink,
                system.statsOutboundDownlink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boolRow(BuildContext context, String title, bool value) {
    return SettingRow(
      title: title,
      value: value
          ? AppLocalizations.of(context)!.switchEnabled
          : AppLocalizations.of(context)!.chainProxyPageDisabled,
    );
  }
}
