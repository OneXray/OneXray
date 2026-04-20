import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/tun/installed_app/controller.dart';
import 'package:onexray/pages/setting/tun/installed_app/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';

class InstalledAppPage extends StatelessWidget {
  final InstalledAppParams params;

  const InstalledAppPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InstalledAppController(params),
      child: BlocBuilder<InstalledAppController, InstalledAppState>(
        builder: (context, state) {
          final controller = context.read<InstalledAppController>();
          return Scaffold(
            appBar: AppBar(
              title:
                  Text(AppLocalizations.of(context)!.installedAppPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    InstalledAppState state,
    InstalledAppController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: _mainBody(context, state, controller),
    );
  }

  Widget _mainBody(
    BuildContext context,
    InstalledAppState state,
    InstalledAppController controller,
  ) {
    return Column(
      children: [
        _search(context, controller),
        Expanded(child: _appList(context, state, controller)),
        _bottomButton(context, controller),
      ],
    );
  }

  Widget _search(BuildContext context, InstalledAppController controller) {
    return TextField(
      controller: controller.searchController,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
      onChanged: (value) => controller.keywordChanged(value),
    );
  }

  Widget _appList(
    BuildContext context,
    InstalledAppState state,
    InstalledAppController controller,
  ) {
    if (state.apps.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.installedAppPageNoApp),
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
    InstalledAppState state,
    InstalledAppController controller,
    int index,
  ) {
    final app = state.apps[index];
    return CheckboxListTile(
      value: state.selections.contains(app.packageName),
      onChanged: (value) => controller.updateSelections(value, app.packageName),
      title: Text(app.name),
      subtitle: Text(app.packageName),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    InstalledAppController controller,
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
