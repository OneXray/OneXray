import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/component/config_row/grid_card.dart';
import 'package:onexray/pages/home/widget/config_grid_list.dart';
import 'package:onexray/pages/subscriptions/nodes/controller.dart';
import 'package:onexray/pages/subscriptions/nodes/params.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';

class SubscriptionNodesPage extends StatelessWidget {
  final SubscriptionNodesParams params;

  const SubscriptionNodesPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionNodesController(params),
      child: BlocBuilder<SubscriptionNodesController, SubscriptionNodesState>(
        builder: (context, state) {
          final controller = context.read<SubscriptionNodesController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(_title(context, state)),
              actions: [
                IconButton(
                  onPressed: () => controller.toggleSearch(),
                  icon: Icon(state.searching ? Icons.close : Icons.search),
                ),
              ],
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  String _title(BuildContext context, SubscriptionNodesState state) {
    if (state.subscriptionName.isNotEmpty) {
      return state.subscriptionName;
    }
    return AppLocalizations.of(context)!.subscriptionListPageTitle;
  }

  Widget _body(
    BuildContext context,
    SubscriptionNodesController controller,
    SubscriptionNodesState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ConfigGridContentFrame(
        child: Column(
          children: [
            if (state.searching) _search(context, controller),
            Expanded(child: _configList(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _search(BuildContext context, SubscriptionNodesController controller) {
    return ListSearchField(
      controller: controller.searchController,
      hintText: AppLocalizations.of(context)!.listSearchHint,
      onChanged: (value) => controller.updateSearchQuery(value),
    );
  }

  Widget _configList(BuildContext context, SubscriptionNodesState state) {
    if (state.configs.isEmpty) {
      return ListEmptyView(
        message: _emptyMessage(context, state),
        icon: state.query.isEmpty ? Icons.hub_outlined : Icons.search_off,
      );
    }
    final runningId = context.select<AppEventBus, int>(
      (eventBus) => eventBus.state.runningId,
    );
    return CustomScrollView(
      slivers: [
        _configGridSliver(configs: state.configs, runningId: runningId),
        const SliverPadding(padding: EdgeInsetsDirectional.only(bottom: 12)),
      ],
    );
  }

  String _emptyMessage(BuildContext context, SubscriptionNodesState state) {
    if (state.missing) {
      return AppLocalizations.of(context)!.subscriptionListPageEmpty;
    }
    if (state.query.isNotEmpty) {
      return AppLocalizations.of(context)!.listNoSearchResult;
    }
    return AppLocalizations.of(context)!.homeOutboundViewNoOutbound;
  }

  Widget _configGridSliver({
    required List<CoreConfigData> configs,
    required int runningId,
  }) {
    return SliverPadding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 12),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnCount(constraints.crossAxisExtent);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 128,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final config = configs[index];
              return ConfigGridCard(
                data: config,
                status: config.id == runningId
                    ? ConfigRowStatus.running
                    : ConfigRowStatus.unselected,
                moreMenus: const [
                  IconMenuId.edit,
                  IconMenuId.share,
                  IconMenuId.copy,
                  IconMenuId.delete,
                ],
                tapCallback: null,
              );
            }, childCount: configs.length),
          );
        },
      ),
    );
  }

  int _columnCount(double width) {
    const minTileWidth = 200;
    const minColumns = 2;
    const maxColumns = 3;
    final rawCount = (width / minTileWidth).floor();
    return rawCount.clamp(minColumns, maxColumns).toInt();
  }
}
