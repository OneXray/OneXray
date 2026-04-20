import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/geo_data/list/params.dart';
import 'package:onexray/pages/geo_data/list/controller.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
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
              title:
                  Text(AppLocalizations.of(context)!.geoDataListPageTitle),
              actions: [
                IconButton(
                  onPressed: () => controller.addGeoData(context),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            body: SafeArea(child: _body(context, controller, state)),
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
        return _geoDataList(context, controller, state);
      case GeoDatCodesMode.select:
        return Column(
          children: [
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
    return ListView.separated(
      itemBuilder: (ctx, index) => _itemRow(ctx, controller, state, index),
      itemCount:
          state.geoDataList.length +
          state.systemGeoDataList.length +
          2,
      separatorBuilder: (_, _) => const Divider(),
    );
  }

  Widget _itemRow(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListState state,
    int index,
  ) {
    if (state.systemGeoDataList.isEmpty) {
      switch (index) {
        case 0:
          return _systemHeader(context, controller);
        case 1:
          return _customHeader(context, controller);
        default:
          return _customCell(
            context,
            controller,
            state.geoDataList[index - 2],
          );
      }
    } else {
      switch (state.type) {
        case GeoDataListType.full:
          return _fullItemRow(context, controller, state, index);
        case GeoDataListType.domain:
        case GeoDataListType.ip:
          return _selectItemRow(context, controller, state, index);
      }
    }
  }

  Widget _fullItemRow(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListState state,
    int index,
  ) {
    switch (index) {
      case 0:
        return _systemHeader(context, controller);
      case 1:
        return _systemCell(
          context,
          controller,
          state.systemGeoDataList[0],
        );
      case 2:
        return _systemCell(
          context,
          controller,
          state.systemGeoDataList[1],
        );
      case 3:
        return _customHeader(context, controller);
      default:
        return _customCell(
          context,
          controller,
          state.geoDataList[index - 4],
        );
    }
  }

  Widget _selectItemRow(
    BuildContext context,
    GeoDataListController controller,
    GeoDataListState state,
    int index,
  ) {
    switch (index) {
      case 0:
        return _systemHeader(context, controller);
      case 1:
        return _systemCell(
          context,
          controller,
          state.systemGeoDataList[0],
        );
      case 2:
        return _customHeader(context, controller);
      default:
        return _customCell(
          context,
          controller,
          state.geoDataList[index - 3],
        );
    }
  }

  Widget _systemHeader(BuildContext context, GeoDataListController controller) {
    return Container(
      padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
      color: ColorManager.surface(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.geoDataListPageSystem,
              style: TextStyle(
                fontSize: 15,
                color: ColorManager.primaryText(context),
              ),
            ),
          ),
          BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, state) =>
                _systemRefreshButton(context, controller, state),
          ),
        ],
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
      return const CircularProgressIndicator();
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
    return InkWell(
      onTap: () => controller.gotoGeoData(context, data),
      child: Container(
        padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
        color: ColorManager.surface(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: ColorManager.primaryText(context),
                    ),
                  ),
                  Row(children: _tags(data)),
                  DateView(date: data.timestamp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customHeader(BuildContext context, GeoDataListController controller) {
    return Container(
      padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
      color: ColorManager.surface(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.geoDataListPageCustom,
              style: TextStyle(
                fontSize: 15,
                color: ColorManager.primaryText(context),
              ),
            ),
          ),
          BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, state) => _customRefreshButton(state),
          ),
        ],
      ),
    );
  }

  Widget _customRefreshButton(AppEventBusState state) {
    final downloading = state.downloading;
    if (downloading) {
      return const CircularProgressIndicator();
    } else {
      return Container();
    }
  }

  Widget _customCell(
    BuildContext context,
    GeoDataListController controller,
    GeoDataData data,
  ) {
    return InkWell(
      onTap: () => controller.gotoGeoData(context, data),
      child: Container(
        padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
        color: ColorManager.surface(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: ColorManager.primaryText(context),
                    ),
                  ),
                  Row(children: _tags(data)),
                  DateView(date: data.timestamp),
                ],
              ),
            ),
            IconMenuPicker(
              icon: Icons.more_vert,
              menus: [IconMenuId.refresh, IconMenuId.share, IconMenuId.delete],
              callback: (menuId) =>
                  controller.moreAction(context, data, menuId),
            ),
          ],
        ),
      ),
    );
  }

  List<TagView> _tags(GeoDataData data) {
    final tags = <TagView>[];
    final type = GeoDataType.fromString(data.type);
    if (type != null) {
      tags.add(TagView(tag: type.name));
    }
    if (data.categoryCount > 0) {
      tags.add(TagView(tag: "${data.categoryCount}"));
    }
    if (data.ruleCount > 0) {
      tags.add(TagView(tag: "${data.ruleCount}"));
    }
    return tags;
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
