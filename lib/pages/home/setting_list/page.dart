import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/component/config_row/view.dart';
import 'package:onexray/pages/home/component/subscription_row/view.dart';
import 'package:onexray/pages/home/setting_list/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';

class XraySettingListPage extends StatelessWidget {
  const XraySettingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XraySettingListController(),
      child: BlocBuilder<XraySettingListController, XraySettingListState>(
        builder: (context, state) {
          final controller = context.read<XraySettingListController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(
                AppLocalizations.of(context)!.xraySettingListPageTitle,
              ),
              actions: [
                IconButton(
                  onPressed: () => controller.toggleSearch(),
                  icon: Icon(state.searching ? Icons.close : Icons.search),
                ),
                IconButton(
                  onPressed: () => controller.addXraySetting(context),
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
    XraySettingListController controller,
    XraySettingListState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          if (state.searching) _search(context, controller),
          Expanded(child: _xraySettingList(context, controller, state)),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _search(BuildContext context, XraySettingListController controller) {
    return ListSearchField(
      controller: controller.searchController,
      hintText: AppLocalizations.of(context)!.listSearchHint,
      onChanged: (value) => controller.updateSearchQuery(value),
    );
  }

  Widget _xraySettingList(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
  ) {
    final rows = _rows(context, controller, state);
    if (rows.isEmpty) {
      return ListEmptyView(
        message: state.query.isEmpty
            ? AppLocalizations.of(context)!.xraySettingListPageEmpty
            : AppLocalizations.of(context)!.listNoSearchResult,
        icon: state.query.isEmpty ? Icons.tune : Icons.search_off,
        actionLabel: state.query.isEmpty
            ? AppLocalizations.of(context)!.buttonAdd
            : null,
        actionIcon: Icons.add,
        onAction: state.query.isEmpty
            ? () => controller.addXraySetting(context)
            : null,
      );
    }
    return ListView.separated(
      itemBuilder: (ctx, index) => rows[index],
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(),
    );
  }

  List<Widget> _rows(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
  ) {
    final rows = <Widget>[];
    final simpleConfigs = state.simpleConfigs.whereType<ConfigItem>().toList();
    if (simpleConfigs.isNotEmpty) {
      rows.add(
        DataListSectionHeader(
          title: _sectionTitle(
            AppLocalizations.of(context)!.xraySettingListPageSimple,
            simpleConfigs.length,
          ),
        ),
      );
      rows.addAll(
        simpleConfigs.map(
          (row) => _simpleConfigRow(context, controller, state, row),
        ),
      );
    }

    if (state.configs.isNotEmpty) {
      rows.add(
        DataListSectionHeader(
          title: _sectionTitle(
            AppLocalizations.of(context)!.xraySettingListPageCustom,
            _configCount(state.configs),
          ),
        ),
      );
      rows.addAll(
        state.configs.map((row) => _customRow(context, controller, state, row)),
      );
    }
    return rows;
  }

  String _sectionTitle(String title, int count) {
    return "$title ($count)";
  }

  int _configCount(List<ConfigQueryRow> rows) {
    final count = rows.whereType<ConfigItem>().length;
    return count == 0 ? rows.length : count;
  }

  Widget _customRow(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
    ConfigQueryRow row,
  ) {
    switch (row.rowType) {
      case ConfigQueryRowType.subscription:
        return _subscriptionRow(context, controller, row);
      case ConfigQueryRowType.config:
        return _configRow(context, controller, state, row);
    }
  }

  Widget _subscriptionRow(
    BuildContext context,
    XraySettingListController controller,
    ConfigQueryRow row,
  ) {
    final item = row as SubscriptionItem;
    return SubscriptionRowView(
      item: item,
      pingCallback: null,
      expandCallback: () => controller.refreshData(),
    );
  }

  Widget _simpleConfigRow(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
    ConfigItem item,
  ) {
    final data = item.config;
    return ConfigRowView(
      data: data,
      status: data.id == state.xraySettingId
          ? ConfigRowStatus.selected
          : ConfigRowStatus.unselected,
      moreMenus: [IconMenuId.edit],
      tapCallback: () => controller.updateXraySettingId(context, data.id),
    );
  }

  Widget _configRow(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
    ConfigQueryRow row,
  ) {
    final item = row as ConfigItem;
    final data = item.config;
    return ConfigRowView(
      data: data,
      status: data.id == state.xraySettingId
          ? ConfigRowStatus.selected
          : ConfigRowStatus.unselected,
      moreMenus: [
        IconMenuId.edit,
        IconMenuId.share,
        IconMenuId.copy,
        IconMenuId.delete,
      ],
      tapCallback: () => controller.updateXraySettingId(context, data.id),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    XraySettingListController controller,
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
