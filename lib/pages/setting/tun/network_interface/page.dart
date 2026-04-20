import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/tun/network_interface/controller.dart';
import 'package:onexray/pages/setting/tun/network_interface/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';

class NetworkInterfacePage extends StatelessWidget {
  final NetworkInterfaceParams params;

  const NetworkInterfacePage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NetworkInterfaceController(params),
      child: BlocBuilder<NetworkInterfaceController, NetworkInterfaceState>(
        builder: (context, state) {
          final controller = context.read<NetworkInterfaceController>();
          return Scaffold(
            appBar: AppBar(
              title:
                  Text(AppLocalizations.of(context)!.networkInterfacePageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    NetworkInterfaceState state,
    NetworkInterfaceController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(child: _list(context, state, controller)),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    NetworkInterfaceState state,
    NetworkInterfaceController controller,
  ) {
    if (state.interfaceList.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.networkInterfacePageNoInterface,
        ),
      );
    } else {
      return RadioGroup<String>(
        onChanged: (value) => controller.updateInterface(value),
        groupValue: state.currentInterface,
        child: ListView.separated(
          itemBuilder: (ctx, index) => _cell(ctx, state, index),
          itemCount: state.interfaceList.length,
          separatorBuilder: (_, _) => const Divider(),
        ),
      );
    }
  }

  Widget _cell(
    BuildContext context,
    NetworkInterfaceState state,
    int index,
  ) {
    final interface = state.interfaceList[index];
    final address = interface.addresses.map((e) => e.address).join("\n");
    return RadioListTile(
      value: interface.name,
      title: Text(interface.name),
      subtitle: Text(address),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    NetworkInterfaceController controller,
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
