import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/geo_data/list/controller.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GeoDataListPage extends StatelessWidget {
  final GeoDataListParams params;

  const GeoDataListPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeoDataListController(params),
      child: BlocBuilder<GeoDataListController, GeoDataListPageState>(
        builder: (context, state) {
          final controller = context.read<GeoDataListController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.geoDataListPageTitle,
            actions: [
              IconButton(
                onPressed: controller.toggleSearch,
                icon: Icon(
                  state.searching ? LucideIcons.x : LucideIcons.search,
                ),
              ),
              IconButton(
                tooltip: localizations.buttonAdd,
                onPressed: () => controller.addGeoData(context),
                icon: const Icon(LucideIcons.plus),
              ),
            ],
            body: ResponsiveContent(
              desktopMaxWidth: 920,
              adaptiveBreakpoint: 840,
              child: _body(context, controller, state),
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListPageState state,
  ) {
    return Column(
      children: [
        if (state.searching) _search(context, controller),
        Expanded(child: _geoDataList(context, controller, state)),
        if (state.mode == GeoDatCodesMode.select)
          _bottomButton(context, controller),
      ],
    );
  }

  Widget _geoDataList(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListPageState state,
  ) {
    final systemGeoDataList = controller.filterSystemGeoDataList();
    if (state.query.isNotEmpty &&
        systemGeoDataList.isEmpty &&
        state.geoDataList.isEmpty) {
      return ListEmptyView(
        message: AppLocalizations.of(context)!.listNoSearchResult,
        icon: LucideIcons.searchX,
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      children: [
        SettingSection(
          title: _sectionTitle(
            AppLocalizations.of(context)!.geoDataListPageSystem,
            systemGeoDataList.length,
          ),
          action: BlocBuilder<AppEventBus, AppEventBusState>(
            bloc: AppEventBus.instance,
            builder: (context, eventState) =>
                _systemRefreshButton(context, controller, eventState),
          ),
          children: systemGeoDataList.isEmpty
              ? [
                  DataListInlineEmptyRow(
                    message: AppLocalizations.of(context)!.listNoSearchResult,
                    icon: LucideIcons.searchX,
                  ),
                ]
              : systemGeoDataList
                    .map((data) => _systemCell(context, controller, data))
                    .toList(),
        ),
        SettingSection(
          title: _sectionTitle(
            AppLocalizations.of(context)!.geoDataListPageCustom,
            state.geoDataList.length,
          ),
          action: BlocBuilder<AppEventBus, AppEventBusState>(
            bloc: AppEventBus.instance,
            builder: (context, eventState) => eventState.downloading
                ? _headerProgressIndicator()
                : const SizedBox.shrink(),
          ),
          children: state.geoDataList.isEmpty
              ? [
                  DataListInlineEmptyRow(
                    message: state.query.isEmpty
                        ? AppLocalizations.of(
                            context,
                          )!.geoDataListPageEmptyCustom
                        : AppLocalizations.of(context)!.listNoSearchResult,
                    icon: state.query.isEmpty
                        ? LucideIcons.folderX
                        : LucideIcons.searchX,
                  ),
                ]
              : state.geoDataList
                    .map((data) => _customCell(context, controller, data))
                    .toList(),
        ),
      ],
    );
  }

  Widget _search(BuildContext context, GeoDataListController controller) {
    return ListSearchField(
      controller: controller.searchController,
      hintText: AppLocalizations.of(context)!.listSearchHint,
      onChanged: (value) => controller.updateSearchQuery(value),
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
        tooltip: AppLocalizations.of(context)!.menuRefresh,
        onPressed: () => controller.refreshSystemGeoDat(context),
        icon: const Icon(LucideIcons.refreshCw),
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
      leading: Icon(
        GeoDataType.fromString(data.type) == GeoDataType.domain
            ? LucideIcons.globe2
            : LucideIcons.listFilter,
      ),
      subtitle: data.url.isEmpty ? null : data.url,
      tags: _tags(context, data),
      meta: DateView(date: data.timestamp),
      onTap: () => controller.gotoGeoData(context, data),
      trailing: const Icon(LucideIcons.chevronRight),
    );
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
      leading: Icon(
        GeoDataType.fromString(data.type) == GeoDataType.domain
            ? LucideIcons.globe2
            : LucideIcons.listFilter,
      ),
      subtitle: data.url.isEmpty ? null : data.url,
      tags: _tags(context, data),
      meta: DateView(date: data.timestamp),
      onTap: () => controller.gotoGeoData(context, data),
      trailing: ActionCluster(
        children: [
          AppMenuButton<IconMenuId>(
            icon: LucideIcons.ellipsis,
            entries: iconMenuEntries([
              IconMenuId.refresh,
              IconMenuId.share,
              IconMenuId.delete,
            ]),
            onSelected: (menuId) =>
                controller.moreAction(context, data, menuId),
          ),
          const Icon(LucideIcons.chevronRight),
        ],
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
