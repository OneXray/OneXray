import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/ad_row/view.dart';
import 'package:onexray/pages/home/component/config_row/selectable_view.dart';
import 'package:onexray/pages/home/component/subscription_row/view.dart';
import 'package:onexray/pages/home/home/component/raw/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';

class HomeRawView extends StatelessWidget {
  const HomeRawView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeRawController, HomeRawState>(
      builder: (context, state) {
        final controller = context.read<HomeRawController>();
        return _body(context, controller, state);
      },
    );
  }

  Widget _body(
    BuildContext context,
    HomeRawController controller,
    HomeRawState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          if (state.searching) _search(context, controller),
          Expanded(child: _configList(context, controller, state)),
        ],
      ),
    );
  }

  Widget _search(BuildContext context, HomeRawController controller) {
    return ListSearchField(
      controller: controller.searchController,
      hintText: AppLocalizations.of(context)!.listSearchHint,
      onChanged: (value) => controller.updateSearchQuery(value),
    );
  }

  Widget _configList(
    BuildContext context,
    HomeRawController controller,
    HomeRawState state,
  ) {
    if (state.configs.isEmpty) {
      return ListEmptyView(
        message: state.query.isEmpty
            ? AppLocalizations.of(context)!.homeOutboundViewNoOutbound
            : AppLocalizations.of(context)!.listNoSearchResult,
        icon: state.query.isEmpty ? Icons.data_object : Icons.search_off,
      );
    } else {
      return ListView.separated(
        itemBuilder: (ctx, index) => _itemRow(ctx, controller, state, index),
        itemCount: state.configs.length,
        separatorBuilder: (_, _) => const Divider(),
      );
    }
  }

  Widget _itemRow(
    BuildContext context,
    HomeRawController controller,
    HomeRawState state,
    int index,
  ) {
    final row = state.configs[index];
    switch (row.rowType) {
      case ConfigQueryRowType.subscription:
        return _subscriptionRow(context, controller, row);
      case ConfigQueryRowType.config:
        return _configRow(context, row);
      case ConfigQueryRowType.ads:
        return GoogleAdsRow();
    }
  }

  Widget _subscriptionRow(
    BuildContext context,
    HomeRawController controller,
    ConfigQueryRow row,
  ) {
    final item = row as SubscriptionItem;
    return SubscriptionRowView(
      item: item,
      pingCallback: () => controller.ping(item.subscription.id),
      expandCallback: () => controller.refreshData(),
    );
  }

  Widget _configRow(BuildContext context, ConfigQueryRow row) {
    return SelectableConfigRow(item: row as ConfigItem);
  }
}
