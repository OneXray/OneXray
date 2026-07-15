import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/geo_data/show/controller.dart';
import 'package:onexray/pages/core/geo_data/show/params.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GeoDatShowPage extends StatelessWidget {
  final GeoDatShowParams params;

  const GeoDatShowPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeoDatShowController(params),
      child: BlocBuilder<GeoDatShowController, GeoDatShowPageState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(state.geoDatName)),
          body: SafeArea(
            child: ResponsiveContent(
              desktopMaxWidth: 920,
              adaptiveBreakpoint: 840,
              child: _body(context, state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, GeoDatShowPageState state) {
    final controller = context.read<GeoDatShowController>();
    return Column(
      children: [
        _search(context, controller),
        Expanded(child: _geoDataList(context, state)),
      ],
    );
  }

  Widget _search(BuildContext context, GeoDatShowController controller) {
    return ListSearchField(
      controller: controller.searchController,
      onChanged: (value) => controller.keywordChanged(value),
    );
  }

  Widget _geoDataList(BuildContext context, GeoDatShowPageState state) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
      child: ShadCard(
        width: double.infinity,
        padding: EdgeInsets.zero,
        radius: const BorderRadius.all(Radius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: state.geoDatCodes.isEmpty
            ? ListEmptyView(
                message: AppLocalizations.of(context)!.geoDatCodesPageNoCodes,
                icon: LucideIcons.searchX,
              )
            : ListView.separated(
                itemBuilder: (ctx, index) => _itemRow(ctx, state, index),
                itemCount: state.geoDatCodes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
              ),
      ),
    );
  }

  Widget _itemRow(BuildContext context, GeoDatShowPageState state, int index) {
    final code = state.geoDatCodes[index];
    final count = code.ruleCount ?? 0;
    return DataListRow(
      title: code.code ?? "",
      tags: [
        TagView(
          tag: AppLocalizations.of(context)!.geoDataListPageRuleCount(count),
        ),
      ],
    );
  }
}
