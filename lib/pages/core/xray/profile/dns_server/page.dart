import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/dns_server/controller.dart';
import 'package:onexray/pages/core/xray/profile/dns_server/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DnsServerPage extends StatelessWidget {
  final DnsServerParams params;

  const DnsServerPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DnsServerController(params),
      child: BlocBuilder<DnsServerController, DnsServerPageState>(
        builder: (context, state) {
          final controller = context.read<DnsServerController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.dnsServerPageTitle,
            onSave: () => controller.save(context),
            body: SettingsPageScroll(
              desktopMaxWidth: 980,
              child: SettingsResponsiveColumns(
                firstFlex: 5,
                secondFlex: 5,
                first: [
                  _addressSection(context, controller, state),
                  _policySection(context, controller, state),
                ],
                second: [
                  _domainsSection(context, controller),
                  _expectedIPsSection(context, controller),
                  _unexpectedIPsSection(context, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _addressSection(
    BuildContext context,
    DnsServerController controller,
    DnsServerPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.dnsServerPageSectionAddress,
      children: [
        TextFieldSettingRow(
          controller: controller.addressController,
          label: localizations.dnsServerPageAddress,
          hintText: localizations.dnsServerPageAddressExample,
        ),
        TextFieldSettingRow(
          controller: controller.portController,
          label: localizations.dnsServerPagePort,
          hintText: localizations.dnsServerPagePortExample,
          keyboardType: TextInputType.number,
        ),
        TextFieldSettingRow(
          controller: controller.clientIpController,
          label: localizations.dnsServerPageClientIp,
          hintText: localizations.dnsServerPageClientIpExample,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.cornerDownLeft),
          title: localizations.dnsServerPageSkipFallback,
          value: state.serverState.skipFallback,
          onChanged: controller.updateSkipFallback,
        ),
      ],
    );
  }

  Widget _policySection(
    BuildContext context,
    DnsServerController controller,
    DnsServerPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.dnsServerPageSectionPolicy,
      children: [
        TextFieldSettingRow(
          controller: controller.tagController,
          label: localizations.dnsServerPageTag,
          hintText: localizations.dnsServerPageTag,
        ),
        TextFieldSettingRow(
          controller: controller.timeoutMsController,
          label: localizations.dnsServerPageTimeoutMs,
          hintText: localizations.dnsServerPageTimeoutMsExample,
          keyboardType: TextInputType.number,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.databaseZap),
          title: localizations.dnsServerPageDisableCache,
          value: state.serverState.disableCache,
          onChanged: controller.updateDisableCache,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.history),
          title: localizations.dnsServerPageServeStale,
          value: state.serverState.serveStale,
          onChanged: controller.updateServeStale,
        ),
        TextFieldSettingRow(
          controller: controller.serveExpiredTTLController,
          label: localizations.dnsServerPageServeExpiredTTL,
          hintText: localizations.dnsServerPageServeExpiredTTLExample,
          keyboardType: TextInputType.number,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.flag),
          title: localizations.dnsServerPageFinalQuery,
          value: state.serverState.finalQuery,
          onChanged: controller.updateFinalQuery,
        ),
      ],
    );
  }

  Widget _domainsSection(BuildContext context, DnsServerController controller) {
    final localizations = AppLocalizations.of(context)!;
    return _matchingSection(
      context: context,
      title: localizations.dnsServerPageSectionDomains,
      fieldLabel: localizations.dnsServerPageDomain,
      hintText: localizations.dnsServerPageDomainExample,
      controllers: controller.domainsControllers,
      onAdd: controller.appendDomains,
      onImport: () => controller.importDomain(context),
      onDelete: (index) => controller.deleteDomains(context, index),
    );
  }

  Widget _expectedIPsSection(
    BuildContext context,
    DnsServerController controller,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return _matchingSection(
      context: context,
      title: localizations.dnsServerPageSectionExpectedIPs,
      fieldLabel: localizations.dnsServerPageIp,
      hintText: localizations.dnsServerPageIpExample,
      controllers: controller.expectedIPsControllers,
      onAdd: controller.appendExpectedIPs,
      onImport: () => controller.importExpectedIPs(context),
      onDelete: (index) => controller.deleteExpectedIPs(context, index),
    );
  }

  Widget _unexpectedIPsSection(
    BuildContext context,
    DnsServerController controller,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return _matchingSection(
      context: context,
      title: localizations.dnsServerPageSectionUnexpectedIPs,
      fieldLabel: localizations.dnsServerPageIp,
      hintText: localizations.dnsServerPageIpExample,
      controllers: controller.unexpectedIPsControllers,
      onAdd: controller.appendUnexpectedIPs,
      onImport: () => controller.importUnexpectedIPs(context),
      onDelete: (index) => controller.deleteUnexpectedIPs(context, index),
    );
  }

  Widget _matchingSection({
    required BuildContext context,
    required String title,
    required String fieldLabel,
    required String hintText,
    required List<TextEditingController> controllers,
    required VoidCallback onAdd,
    required VoidCallback onImport,
    required ValueChanged<int> onDelete,
  }) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: title,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: localizations.buttonAdd,
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
          ),
          IconButton(
            tooltip: localizations.buttonImport,
            onPressed: onImport,
            icon: const Icon(LucideIcons.listFilter),
          ),
        ],
      ),
      children: controllers
          .mapIndexed(
            (index, textController) => TextFieldActionSettingRow(
              controller: textController,
              label: fieldLabel,
              showLabel: false,
              hintText: hintText,
              trailing: IconButton(
                tooltip: localizations.menuDelete,
                onPressed: () => onDelete(index),
                icon: const Icon(LucideIcons.trash2),
              ),
            ),
          )
          .toList(),
    );
  }
}
