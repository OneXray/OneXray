import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/tun/network_interface/controller.dart';
import 'package:onexray/pages/core/tun/network_interface/params.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NetworkInterfacePage extends StatelessWidget {
  final NetworkInterfaceParams params;

  const NetworkInterfacePage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NetworkInterfaceController(params),
      child: BlocBuilder<NetworkInterfaceController, NetworkInterfacePageState>(
        builder: (context, state) {
          final controller = context.read<NetworkInterfaceController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.networkInterfacePageTitle,
            onSave: () => controller.save(context),
            body: ResponsiveContent(
              desktopMaxWidth: 760,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 20),
                child: _interfaceCard(context, state, controller),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _interfaceCard(
    BuildContext context,
    NetworkInterfacePageState state,
    NetworkInterfaceController controller,
  ) {
    if (state.interfaceList.isEmpty) {
      return ListEmptyView(
        message: AppLocalizations.of(context)!.networkInterfacePageNoInterface,
      );
    }
    return ShadCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: RadioGroup<String>(
        onChanged: controller.updateInterface,
        groupValue: state.currentInterface,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: state.interfaceList.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _cell(context, state, controller, index),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    NetworkInterfacePageState state,
    NetworkInterfaceController controller,
    int index,
  ) {
    final interface = state.interfaceList[index];
    final address = interface.addresses
        .map((value) => value.address)
        .join("\n");
    return DataListRow(
      title: interface.name,
      subtitle: address,
      onTap: () => controller.updateInterface(interface.name),
      trailing: Radio<String>(value: interface.name),
    );
  }
}
