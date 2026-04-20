import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/ad_row/view.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/component/config_row/view.dart';
import 'package:onexray/pages/home/component/subscription_row/view.dart';
import 'package:onexray/pages/home/setting_list/controller.dart';
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
                  AppLocalizations.of(context)!.xraySettingListPageTitle),
              actions: [
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
          Expanded(child: _xraySettingList(context, controller, state)),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _xraySettingList(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
  ) {
    return ListView.separated(
      itemBuilder: (ctx, index) =>
          _itemRow(ctx, controller, state, index),
      itemCount: state.configs.length + state.simpleConfigs.length,
      separatorBuilder: (_, _) => const Divider(),
    );
  }

  Widget _itemRow(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
    int index,
  ) {
    if (index >= 0 && index < 2) {
      return _simpleCell(context, controller, state, index);
    } else {
      return _cell(context, controller, state, index - 2);
    }
  }

  Widget _simpleCell(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
    int index,
  ) {
    final row = state.simpleConfigs[index];
    switch (row.rowType) {
      case ConfigQueryRowType.subscription:
        final item = row as SubscriptionItem;
        return SubscriptionRowView(
          item: item,
          pingCallback: null,
          expandCallback: null,
        );
      case ConfigQueryRowType.config:
        return _simpleConfigRow(context, controller, state, row);
      case ConfigQueryRowType.ads:
        return GoogleAdsRow();
    }
  }

  Widget _simpleConfigRow(
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
      moreMenus: [IconMenuId.edit],
      tapCallback: () => controller.updateXraySettingId(context, data.id),
    );
  }

  Widget _cell(
    BuildContext context,
    XraySettingListController controller,
    XraySettingListState state,
    int index,
  ) {
    final row = state.configs[index];
    switch (row.rowType) {
      case ConfigQueryRowType.subscription:
        return _subscriptionRow(context, controller, row);
      case ConfigQueryRowType.config:
        return _configRow(context, controller, state, row);
      case ConfigQueryRowType.ads:
        return GoogleAdsRow();
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
