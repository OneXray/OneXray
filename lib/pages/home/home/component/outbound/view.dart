import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/ad_row/view.dart';
import 'package:onexray/pages/home/component/config_row/selectable_view.dart';
import 'package:onexray/pages/home/component/subscription_row/view.dart';
import 'package:onexray/pages/home/home/component/outbound/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/text_action_row.dart';

class HomeOutboundView extends StatelessWidget {
  const HomeOutboundView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeOutboundController(),
      child: BlocBuilder<HomeOutboundController, HomeOutboundState>(
        builder: (context, state) {
          final controller = context.read<HomeOutboundController>();
          return _body(context, controller, state);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    HomeOutboundController controller,
    HomeOutboundState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          _xraySetting(context, controller, state),
          Divider(),
          Expanded(child: _configList(context, controller, state)),
        ],
      ),
    );
  }

  Widget _xraySetting(
    BuildContext context,
    HomeOutboundController controller,
    HomeOutboundState state,
  ) {
    return ColoredBox(
      color: ColorManager.surface(context),
      child: TextActionRow(
        title: AppLocalizations.of(context)!.homeOutboundViewXraySetting,
        detail: state.xraySettingName,
        onTap: () => controller.gotoXraySetting(context),
      ),
    );
  }

  Widget _configList(
    BuildContext context,
    HomeOutboundController controller,
    HomeOutboundState state,
  ) {
    if (state.configs.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.homeOutboundViewNoOutbound),
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
    HomeOutboundController controller,
    HomeOutboundState state,
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
    HomeOutboundController controller,
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
