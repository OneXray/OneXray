import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/geo_data/show/controller.dart';
import 'package:onexray/pages/geo_data/show/params.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/tag_view.dart';

class GeoDatShowPage extends StatelessWidget {
  final GeoDatShowParams params;

  const GeoDatShowPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeoDatShowController(params),
      child: BlocBuilder<GeoDatShowController, GeoDatShowState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(state.geoDatName)),
          body: SafeArea(child: _body(context, state)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, GeoDatShowState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: _mainBody(context, state),
    );
  }

  Widget _mainBody(BuildContext context, GeoDatShowState state) {
    final controller = context.read<GeoDatShowController>();
    return Column(
      children: [
        _search(context, controller),
        Expanded(child: _geoDataList(context, state)),
      ],
    );
  }

  Widget _search(BuildContext context, GeoDatShowController controller) {
    return TextField(
      controller: controller.searchController,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
      onChanged: (value) => controller.keywordChanged(value),
    );
  }

  Widget _geoDataList(BuildContext context, GeoDatShowState state) {
    if (state.geoDatCodes.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.geoDatCodesPageNoCodes),
      );
    } else {
      return ListView.separated(
        itemBuilder: (ctx, index) => _itemRow(ctx, state, index),
        itemCount: state.geoDatCodes.length,
        separatorBuilder: (_, _) => const Divider(),
      );
    }
  }

  Widget _itemRow(
    BuildContext context,
    GeoDatShowState state,
    int index,
  ) {
    final code = state.geoDatCodes[index];
    final count = code.ruleCount ?? 0;
    return ListTile(
      title: Text(code.code ?? ""),
      subtitle: Row(children: [TagView(tag: "$count")]),
    );
  }
}
