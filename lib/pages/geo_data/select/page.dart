import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/geo_data/select/controller.dart';
import 'package:onexray/pages/geo_data/select/params.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/tag_view.dart';

class GeoDatSelectPage extends StatelessWidget {
  final GeoDatSelectParams params;

  const GeoDatSelectPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeoDatSelectController(params),
      child: BlocBuilder<GeoDatSelectController, GeoDatSelectState>(
        builder: (context, state) {
          final controller = context.read<GeoDatSelectController>();
          return Scaffold(
            appBar: AppBar(title: Text(state.geoDatName)),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    GeoDatSelectController controller,
    GeoDatSelectState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: _mainBody(context, controller, state),
    );
  }

  Widget _mainBody(
    BuildContext context,
    GeoDatSelectController controller,
    GeoDatSelectState state,
  ) {
    return Column(
      children: [
        _search(context, controller),
        Expanded(child: _geoDataList(context, controller, state)),
        _bottomButton(context, controller),
      ],
    );
  }

  Widget _search(BuildContext context, GeoDatSelectController controller) {
    return TextField(
      controller: controller.searchController,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
      onChanged: (value) => controller.keywordChanged(value),
    );
  }

  Widget _geoDataList(
    BuildContext context,
    GeoDatSelectController controller,
    GeoDatSelectState state,
  ) {
    if (state.geoDatCodes.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.geoDatCodesPageNoCodes),
      );
    } else {
      return ListView.separated(
        itemBuilder: (ctx, index) =>
            _itemRow(ctx, controller, state, index),
        itemCount: state.geoDatCodes.length,
        separatorBuilder: (_, _) => const Divider(),
      );
    }
  }

  Widget _itemRow(
    BuildContext context,
    GeoDatSelectController controller,
    GeoDatSelectState state,
    int index,
  ) {
    final code = state.geoDatCodes[index];
    final count = code.ruleCount ?? 0;
    return CheckboxListTile(
      value: state.selections.contains(code.code),
      onChanged: (value) => controller.updateSelections(value, code.code),
      title: Text(code.code ?? ""),
      subtitle: Row(children: [TagView(tag: "$count")]),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    GeoDatSelectController controller,
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
