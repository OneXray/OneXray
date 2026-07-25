import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';

class FakeDnsView extends StatelessWidget {
  final TextEditingController ipv4IpPoolController;
  final TextEditingController ipv4PoolSizeController;
  final TextEditingController ipv6IpPoolController;
  final TextEditingController ipv6PoolSizeController;

  const FakeDnsView({
    super.key,
    required this.ipv4IpPoolController,
    required this.ipv4PoolSizeController,
    required this.ipv6IpPoolController,
    required this.ipv6PoolSizeController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingsOverviewGrid(
            children: [
              _poolSection(
                context,
                l10n.fakeDnsPageIPv4,
                ipv4IpPoolController,
                ipv4PoolSizeController,
              ),
              _poolSection(
                context,
                l10n.fakeDnsPageIPv6,
                ipv6IpPoolController,
                ipv6PoolSizeController,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _poolSection(
    BuildContext context,
    String title,
    TextEditingController ipPool,
    TextEditingController poolSize,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: title,
      children: [
        TextFieldSettingRow(
          controller: ipPool,
          label: l10n.fakeDnsPageIpPool,
          hintText: l10n.fakeDnsPageIpPool,
        ),
        TextFieldSettingRow(
          controller: poolSize,
          keyboardType: TextInputType.number,
          label: l10n.fakeDnsPagePoolSize,
          hintText: l10n.fakeDnsPagePoolSize,
        ),
      ],
    );
  }
}
