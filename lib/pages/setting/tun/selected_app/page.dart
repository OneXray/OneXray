import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/tun/selected_app/controller.dart';
import 'package:onexray/pages/setting/tun/selected_app/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';

class SelectedAppPage extends StatelessWidget {
  final SelectedAppParams params;

  const SelectedAppPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SelectedAppController(params),
      child: BlocBuilder<SelectedAppController, SelectedAppState>(
        builder: (context, state) {
          final controller = context.read<SelectedAppController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.selectedAppPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SelectedAppState state,
    SelectedAppController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: _mainBody(context, state, controller),
    );
  }

  Widget _mainBody(
    BuildContext context,
    SelectedAppState state,
    SelectedAppController controller,
  ) {
    return Column(
      children: [
        Expanded(child: _appList(context, state, controller)),
        _bottomButton(context, controller),
      ],
    );
  }

  Widget _appList(
    BuildContext context,
    SelectedAppState state,
    SelectedAppController controller,
  ) {
    if (state.apps.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.selectedAppPageNoApp),
      );
    } else {
      return ListView.separated(
        itemBuilder: (ctx, index) =>
            _itemRow(ctx, state, controller, index),
        itemCount: state.apps.length,
        separatorBuilder: (_, _) => const Divider(),
      );
    }
  }

  Widget _itemRow(
    BuildContext context,
    SelectedAppState state,
    SelectedAppController controller,
    int index,
  ) {
    final app = state.apps[index];
    return ListTile(
      title: Text(app.name),
      subtitle: Text(app.packageName),
      trailing: IconMenuPicker(
        icon: Icons.more_vert,
        menus: [IconMenuId.delete],
        callback: (menuId) => controller.moreAction(context, app, menuId),
      ),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    SelectedAppController controller,
  ) {
    return BottomView(
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: SecondaryBottomButton(
              title: AppLocalizations.of(context)!.buttonAdd,
              callback: () => controller.gotoInstalledApp(context),
            ),
          ),
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
