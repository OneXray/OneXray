import 'package:flutter/material.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/pages/home/component/config_row/grid_card.dart';
import 'package:onexray/pages/home/component/subscription_row/view.dart';
import 'package:onexray/pages/widget/data_list.dart';

class ConfigGridContentFrame extends StatelessWidget {
  const ConfigGridContentFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth >= ConfigGridList.adaptiveBreakpoint
            ? ConfigGridList.maxContentWidth
            : double.infinity;
        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class ConfigGridList extends StatelessWidget {
  const ConfigGridList({
    super.key,
    required this.rows,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onPingSubscription,
    required this.onRefresh,
    this.onCleanSubscription,
    this.subscriptionExpandable = true,
  });

  static const double maxContentWidth = 1040;
  static const double adaptiveBreakpoint = 900;
  static const double compactRowVerticalPadding = 4;
  static const double _minTileWidth = 200;
  static const int _minColumns = 2;
  static const int _maxColumns = 3;

  final List<ConfigQueryRow> rows;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(int subId) onPingSubscription;
  final VoidCallback onRefresh;
  final Future<void> Function(int subId)? onCleanSubscription;
  final bool subscriptionExpandable;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return ListEmptyView(message: emptyMessage, icon: emptyIcon);
    }
    return CustomScrollView(slivers: _slivers(context));
  }

  List<Widget> _slivers(BuildContext context) {
    final slivers = <Widget>[];
    var index = 0;
    while (index < rows.length) {
      final row = rows[index];
      switch (row.rowType) {
        case ConfigQueryRowType.subscription:
          slivers.add(_subscriptionSliver(context, row as SubscriptionItem));
          index += 1;
          break;
        case ConfigQueryRowType.config:
          final start = index;
          while (index < rows.length &&
              rows[index].rowType == ConfigQueryRowType.config) {
            index += 1;
          }
          slivers.add(_configGridSliver(start: start, count: index - start));
          break;
      }
    }
    slivers.add(
      const SliverPadding(padding: EdgeInsetsDirectional.only(bottom: 12)),
    );
    return slivers;
  }

  Widget _subscriptionSliver(BuildContext context, SubscriptionItem item) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          SubscriptionRowView(
            item: item,
            pingCallback: () => onPingSubscription(item.subscription.id),
            expandCallback: subscriptionExpandable ? onRefresh : null,
            cleanCallback: onCleanSubscription == null
                ? null
                : (subscription) => onCleanSubscription!(subscription.id),
            compact: true,
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _configGridSliver({required int start, required int count}) {
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
            delegate: SliverChildBuilderDelegate((context, offset) {
              final item = rows[start + offset] as ConfigItem;
              return SelectableConfigGridCard(item: item);
            }, childCount: count),
          );
        },
      ),
    );
  }

  int _columnCount(double width) {
    final rawCount = (width / _minTileWidth).floor();
    return rawCount.clamp(_minColumns, _maxColumns).toInt();
  }
}
