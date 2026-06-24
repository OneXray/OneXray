import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/setting/outbound_black_hole/controller.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class OutboundBlackHolePage extends StatelessWidget {
  const OutboundBlackHolePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OutboundBlackHoleController();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.outboundBlackHolePageTitle),
      ),
      body: SafeArea(child: _body(context, controller)),
    );
  }

  Widget _body(BuildContext context, OutboundBlackHoleController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: ResponsiveContent(child: _section(context, controller)),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    OutboundBlackHoleController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.outboundBlackHolePageProtocol,
          value: controller.blackHoleState.protocol.name,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.outboundBlackHolePageTag,
          value: controller.blackHoleState.tag.name,
        ),
      ],
    );
  }
}
