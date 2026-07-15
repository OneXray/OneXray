import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/subscriptions/list/controller.dart';
import 'package:onexray/pages/subscriptions/list/view.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    final localizations = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return compact
        ? ShadIconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context
                .read<SubscriptionListController>()
                .addSubscription(context),
          )
        : ShadButton(
            leading: const Icon(LucideIcons.plus),
            onPressed: () => context
                .read<SubscriptionListController>()
                .addSubscription(context),
            child: Text(localizations.buttonAdd),
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
    return StreamBuilder<List<SubscriptionItem>>(
      stream: controller.rowsStream,
      builder: (context, snapshot) {
        return BlocBuilder<AppEventBus, AppEventBusState>(
          buildWhen: (previous, current) => previous.pinging != current.pinging,
          builder: (context, eventState) => SubscriptionListView(
            items: snapshot.data ?? const [],
            emptyMessage: AppLocalizations.of(
              context,
            )!.subscriptionListPageEmpty,
            addLabel: AppLocalizations.of(context)!.buttonAdd,
            pingLabel: AppLocalizations.of(context)!.outboundPageRealPing,
            pinging: eventState.pinging,
            onAdd: () => controller.addSubscription(context),
            onOpen: (subscription) =>
                controller.openNodes(context, subscription.id),
            onPing: (subscription) => controller.ping(subscription.id),
            onAction: (subscription, menuId) =>
                controller.moreAction(context, subscription, menuId),
          ),
        );
      },
    );
  }
}
