import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/dns_hosts/controller.dart';
import 'package:onexray/pages/home/xray/setting/dns_hosts/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class DnsHostsPage extends StatelessWidget {
  final DnsHostsParams params;

  const DnsHostsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DnsHostsController(params),
      child: BlocBuilder<DnsHostsController, DnsHostsCubitState>(
        builder: (context, state) {
          final controller = context.read<DnsHostsController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.dnsHostsPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    DnsHostsController controller,
    DnsHostsCubitState state,
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
                    _addSection(context, controller),
                    _hosts(context, controller, state),
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

  Widget _addSection(BuildContext context, DnsHostsController controller) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.dnsHostsPageAdd,
          trailing: IconButton(
            onPressed: () => controller.appendHostAddress(),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _hosts(
    BuildContext context,
    DnsHostsController controller,
    DnsHostsCubitState state,
  ) {
    final hostViews = state.hosts
        .mapIndexed(
          (index, server) => _hostSection(context, controller, server, index),
        )
        .toList();
    return Column(children: hostViews);
  }

  Widget _hostSection(
    BuildContext context,
    DnsHostsController controller,
    XrayHostAddress host,
    int hostIndex,
  ) {
    final addressViews = host.address
        .mapIndexed(
          (index, address) => Row(
            children: [
              Expanded(
                child: TextFieldActionSettingRow(
                  controller: address,
                  label: AppLocalizations.of(context)!.dnsHostsPageAddress,
                  hintText: AppLocalizations.of(
                    context,
                  )!.dnsHostsPageAddressExample,
                  trailing: IconButton(
                    onPressed: () =>
                        controller.deleteAddress(context, hostIndex, index),
                    icon: Icon(Icons.delete),
                  ),
                ),
              ),
            ],
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      separated: false,
      children: [
        TextFieldActionSettingRow(
          controller: host.host,
          label: AppLocalizations.of(context)!.dnsHostsPageHost,
          hintText: AppLocalizations.of(context)!.dnsHostsPageHostExample,
          trailing: IconButton(
            onPressed: () => controller.deleteHostAddress(context, hostIndex),
            icon: Icon(Icons.delete),
          ),
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.dnsHostsPageAddress,
          trailing: IconButton(
            onPressed: () => controller.appendAddress(context, hostIndex),
            icon: const Icon(Icons.add),
          ),
        ),
        Column(children: addressViews),
      ],
    );
  }

  Widget _bottomButton(BuildContext context, DnsHostsController controller) {
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
