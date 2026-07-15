import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/controller.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DnsHostsPage extends StatelessWidget {
  final DnsHostsParams params;

  const DnsHostsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DnsHostsController(params),
      child: BlocBuilder<DnsHostsController, DnsHostsPageState>(
        builder: (context, state) {
          final controller = context.read<DnsHostsController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.dnsHostsPageTitle,
            onSave: () => controller.save(context),
            actions: [
              IconButton(
                tooltip: localizations.dnsHostsPageAdd,
                onPressed: controller.appendHostAddress,
                icon: const Icon(LucideIcons.plus),
              ),
            ],
            body: SettingsPageScroll(
              desktopMaxWidth: 820,
              child: Column(
                children: state.hosts
                    .mapIndexed(
                      (index, host) =>
                          _hostSection(context, controller, host, index),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hostSection(
    BuildContext context,
    DnsHostsController controller,
    XrayHostAddress host,
    int hostIndex,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: '${localizations.dnsHostsPageHost} ${hostIndex + 1}',
      action: IconButton(
        tooltip: localizations.menuDelete,
        onPressed: () => controller.deleteHostAddress(context, hostIndex),
        icon: const Icon(LucideIcons.trash2),
      ),
      children: [
        TextFieldSettingRow(
          controller: host.host,
          label: localizations.dnsHostsPageHost,
          hintText: localizations.dnsHostsPageHostExample,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.mapPin),
          title: localizations.dnsHostsPageAddress,
          trailing: IconButton(
            tooltip: localizations.buttonAdd,
            onPressed: () => controller.appendAddress(context, hostIndex),
            icon: const Icon(LucideIcons.plus),
          ),
        ),
        ...host.address.mapIndexed(
          (index, address) => TextFieldActionSettingRow(
            controller: address,
            label: localizations.dnsHostsPageAddress,
            showLabel: false,
            hintText: localizations.dnsHostsPageAddressExample,
            trailing: IconButton(
              tooltip: localizations.menuDelete,
              onPressed: () =>
                  controller.deleteAddress(context, hostIndex, index),
              icon: const Icon(LucideIcons.trash2),
            ),
          ),
        ),
      ],
    );
  }
}
