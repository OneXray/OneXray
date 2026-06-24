import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/subscription_row/view.dart';
import 'package:onexray/pages/subscriptions/list/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

class SubscriptionListPage extends StatelessWidget {
  const SubscriptionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionListController(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              AppLocalizations.of(context)!.subscriptionListPageTitle,
            ),
            actions: [_addButton(context)],
          ),
          body: const SafeArea(child: _SubscriptionListView()),
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.subscriptionAddPageTitle,
      onPressed: () =>
          context.read<SubscriptionListController>().addSubscription(context),
      icon: const Icon(Icons.add),
    );
  }
}

class SubscriptionListContent extends StatelessWidget {
  const SubscriptionListContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionListController(),
      child: const _SubscriptionListView(),
    );
  }
}

class _SubscriptionListView extends StatelessWidget {
  const _SubscriptionListView();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SubscriptionListController>();
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: StreamBuilder<List<ConfigQueryRow>>(
        stream: controller.rowsStream,
        builder: (context, snapshot) {
          final items = (snapshot.data ?? const <ConfigQueryRow>[])
              .whereType<SubscriptionItem>()
              .where((item) => item.subscription.id > DBConstants.defaultId)
              .toList();
          return ResponsiveContent(
            desktopMaxWidth: 1040,
            adaptiveBreakpoint: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: _list(context, items))],
            ),
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, List<SubscriptionItem> items) {
    if (items.isEmpty) {
      return ListEmptyView(
        message: AppLocalizations.of(context)!.subscriptionListPageEmpty,
        icon: Icons.dynamic_feed_outlined,
        actionLabel: AppLocalizations.of(context)!.subscriptionAddPageTitle,
        actionIcon: Icons.add,
        onAction: () =>
            context.read<SubscriptionListController>().addSubscription(context),
      );
    }
    return ListView.separated(
      itemBuilder: (context, index) {
        final item = items[index];
        return SubscriptionRowView(
          item: item,
          tapCallback: () => context
              .read<SubscriptionListController>()
              .openNodes(context, item.subscription.id),
          pingCallback: () => context.read<SubscriptionListController>().ping(
            item.subscription.id,
          ),
          expandCallback: null,
        );
      },
      separatorBuilder: (_, _) => const Divider(),
      itemCount: items.length,
    );
  }
}
