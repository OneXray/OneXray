import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/outbounds/controller.dart';
import 'package:onexray/pages/core/xray/full_config/outbounds/params.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/outbound/state.dart';

class XrayFullConfigOutboundsPage extends StatelessWidget {
  final XrayFullConfigOutboundsParams params;

  const XrayFullConfigOutboundsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayFullConfigOutboundsController(params),
      child:
          BlocBuilder<
            XrayFullConfigOutboundsController,
            XrayFullConfigOutboundsPageState
          >(
            builder: (context, state) {
              final controller = context
                  .read<XrayFullConfigOutboundsController>();
              return Scaffold(
                appBar: AppBar(
                  title: Text(AppLocalizations.of(context)!.outboundsPageTitle),
                ),
                body: SafeArea(child: _body(context, controller, state)),
              );
            },
          ),
    );
  }

  Widget _body(
    BuildContext context,
    XrayFullConfigOutboundsController controller,
    XrayFullConfigOutboundsPageState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _primaryProxySection(context, controller),
                    _customOutboundsSection(context, controller),
                    _systemOutboundsSection(context, controller),
                  ],
                ),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _primaryProxySection(
    BuildContext context,
    XrayFullConfigOutboundsController controller,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final proxy = controller.primaryProxy;
    return SettingSection(
      title: localizations.xrayFullConfigPrimaryProxy,
      children: [
        NavigationSettingRow(
          title: proxy?.name ?? localizations.xrayFullConfigProxyMissing,
          value: "proxy",
          onTap: () => controller.editPrimaryProxy(context),
        ),
        SettingRow(
          title: localizations.xrayFullConfigSelectFromNodes,
          leading: const Icon(Icons.playlist_add),
          onTap: () => controller.importPrimaryProxy(context),
        ),
      ],
    );
  }

  Widget _customOutboundsSection(
    BuildContext context,
    XrayFullConfigOutboundsController controller,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final customOutbounds = controller.customOutbounds;
    return SettingSection(
      title: localizations.xrayFullConfigCustomOutbounds,
      children: [
        ...customOutbounds.map(
          (outbound) => _customOutboundRow(context, controller, outbound),
        ),
        SettingRow(
          title: localizations.xrayFullConfigAddCustomOutbound,
          leading: const Icon(Icons.add),
          onTap: () => controller.addCustomOutbound(context),
        ),
        SettingRow(
          title: localizations.xrayFullConfigImportCustomOutbound,
          leading: const Icon(Icons.playlist_add),
          onTap: () => controller.importCustomOutbound(context),
        ),
      ],
    );
  }

  Widget _customOutboundRow(
    BuildContext context,
    XrayFullConfigOutboundsController controller,
    OutboundState outbound,
  ) {
    return SettingRow(
      title: outbound.name,
      value: outbound.tag,
      onTap: () => controller.editCustomOutbound(context, outbound),
      trailing: AppMenuButton<IconMenuId>(
        icon: Icons.more_vert,
        entries: iconMenuEntries([IconMenuId.delete]),
        onSelected: (menu) => controller.customMenuAction(menu, outbound),
      ),
    );
  }

  Widget _systemOutboundsSection(
    BuildContext context,
    XrayFullConfigOutboundsController controller,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.outboundsPageSystem,
      children: [
        NavigationSettingRow(
          title: localizations.outboundFreedomPageTitle,
          value: "direct",
          onTap: () => controller.editFreedom(context),
        ),
        NavigationSettingRow(
          title: localizations.outboundFragmentPageTitle,
          value: "fragment",
          onTap: () => controller.editFragment(context),
        ),
        NavigationSettingRow(
          title: localizations.outboundBlackHolePageTitle,
          value: "block",
          onTap: () => controller.editBlackHole(context),
        ),
        NavigationSettingRow(
          title: localizations.outboundDnsPageTitle,
          value: "dnsOut",
          onTap: () => controller.editDns(context),
        ),
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    XrayFullConfigOutboundsController controller,
  ) {
    return BottomView(
      child: Row(
        children: [
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
}
