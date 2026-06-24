import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/core/geo_data/list/controller.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/geo_data/enum.dart';

class GeoDataListPage extends StatelessWidget {
  final GeoDataListParams params;

  const GeoDataListPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeoDataListController(params),
      child: BlocBuilder<GeoDataListController, GeoDataListState>(
        builder: (context, state) {
          final controller = context.read<GeoDataListController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.geoDataListPageTitle),
              actions: [
                IconButton(
                  onPressed: () => controller.toggleSearch(),
                  icon: Icon(state.searching ? Icons.close : Icons.search),
                ),
                IconButton(
                  onPressed: () => controller.addGeoData(context),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            body: SafeArea(
              child: ResponsiveContent(
                desktopMaxWidth: 880,
                adaptiveBreakpoint: 840,
                child: _body(context, controller, state),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: _mainBody(context, controller, state),
    );
  }

  Widget _mainBody(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListState state,
  ) {
    switch (state.mode) {
      case GeoDatCodesMode.show:
        return Column(
          children: [
            if (state.searching) _search(context, controller),
            Expanded(child: _geoDataList(context, controller, state)),
          ],
        );
      case GeoDatCodesMode.select:
        return Column(
          children: [
            if (state.searching) _search(context, controller),
            Expanded(child: _geoDataList(context, controller, state)),
            _bottomButton(context, controller),
          ],
        );
    }
  }

  Widget _geoDataList(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListState state,
  ) {
    final systemGeoDataList = controller.filterSystemGeoDataList();
    if (state.query.isNotEmpty &&
        systemGeoDataList.isEmpty &&
        state.geoDataList.isEmpty) {
      return ListEmptyView(
        message: AppLocalizations.of(context)!.listNoSearchResult,
        icon: Icons.search_off,
      );
    }
    final rows = <Widget>[
      _systemHeader(context, controller, systemGeoDataList.length),
      ...systemGeoDataList.map(
        (data) => _systemCell(context, controller, data),
      ),
      _customHeader(context, controller, state.geoDataList.length),
      if (state.geoDataList.isEmpty)
        DataListInlineEmptyRow(
          message: state.query.isEmpty
              ? AppLocalizations.of(context)!.geoDataListPageEmptyCustom
              : AppLocalizations.of(context)!.listNoSearchResult,
          icon: state.query.isEmpty
              ? Icons.folder_off_outlined
              : Icons.search_off,
        )
      else
        ...state.geoDataList.map(
          (data) => _customCell(context, controller, data),
        ),
    ];
    return ListView.separated(
      itemBuilder: (ctx, index) => rows[index],
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(),
    );
  }

  Widget _search(BuildContext context, GeoDataListController controller) {
    return ListSearchField(
      controller: controller.searchController,
      hintText: AppLocalizations.of(context)!.listSearchHint,
      onChanged: (value) => controller.updateSearchQuery(value),
    );
  }

  Widget _systemHeader(
    BuildContext context,
    GeoDataListController controller,
    int count,
  ) {
    return DataListSectionHeader(
      title: _sectionTitle(
        AppLocalizations.of(context)!.geoDataListPageSystem,
        count,
      ),
      trailing: BlocBuilder<AppEventBus, AppEventBusState>(
        builder: (context, state) =>
            _systemRefreshButton(context, controller, state),
      ),
    );
  }

  Widget _systemRefreshButton(
    BuildContext context,
    GeoDataListController controller,
    AppEventBusState state,
  ) {
    final downloading = state.downloading;
    if (downloading) {
      return _headerProgressIndicator();
    } else {
      return IconButton(
        onPressed: () => controller.refreshSystemGeoDat(context),
        icon: const Icon(Icons.refresh),
      );
    }
  }

  Widget _systemCell(
    BuildContext context,
    GeoDataListController controller,
    GeoDataData data,
  ) {
    return DataListRow(
      title: data.name,
      subtitle: data.url.isEmpty ? null : data.url,
      tags: _tags(context, data),
      meta: DateView(date: data.timestamp),
      onTap: () => controller.gotoGeoData(context, data),
    );
  }

  Widget _customHeader(
    BuildContext context,
    GeoDataListController controller,
    int count,
  ) {
    return DataListSectionHeader(
      title: _sectionTitle(
        AppLocalizations.of(context)!.geoDataListPageCustom,
        count,
      ),
      trailing: BlocBuilder<AppEventBus, AppEventBusState>(
        builder: (context, state) => _customRefreshButton(state),
      ),
    );
  }

  Widget _customRefreshButton(AppEventBusState state) {
    final downloading = state.downloading;
    if (downloading) {
      return _headerProgressIndicator();
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _headerProgressIndicator() {
    return const SizedBox.square(
      dimension: 48,
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _customCell(
    BuildContext context,
    GeoDataListController controller,
    GeoDataData data,
  ) {
    return DataListRow(
      title: data.name,
      subtitle: data.url.isEmpty ? null : data.url,
      tags: _tags(context, data),
      meta: DateView(date: data.timestamp),
      onTap: () => controller.gotoGeoData(context, data),
      trailing: IconMenuPicker(
        icon: Icons.more_vert,
        menus: [IconMenuId.refresh, IconMenuId.delete],
        callback: (menuId) => controller.moreAction(context, data, menuId),
      ),
    );
  }

  String _sectionTitle(String title, int count) {
    return "$title ($count)";
  }

  List<TagView> _tags(BuildContext context, GeoDataData data) {
    final tags = <TagView>[];
    final type = GeoDataType.fromString(data.type);
    if (type != null) {
      tags.add(TagView(tag: _typeName(context, type)));
    }
    if (data.categoryCount > 0) {
      tags.add(
        TagView(
          tag: AppLocalizations.of(
            context,
          )!.geoDataListPageCategoryCount(data.categoryCount),
        ),
      );
    }
    if (data.ruleCount > 0) {
      tags.add(
        TagView(
          tag: AppLocalizations.of(
            context,
          )!.geoDataListPageRuleCount(data.ruleCount),
        ),
      );
    }
    return tags;
  }

  String _typeName(BuildContext context, GeoDataType type) {
    switch (type) {
      case GeoDataType.domain:
        return AppLocalizations.of(context)!.geoDataListPageTypeDomain;
      case GeoDataType.ip:
        return AppLocalizations.of(context)!.geoDataListPageTypeIp;
    }
  }

  Widget _bottomButton(BuildContext context, GeoDataListController controller) {
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
