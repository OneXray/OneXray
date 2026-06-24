import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/home/component/raw/controller.dart';
import 'package:onexray/pages/home/widget/config_grid_list.dart';
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
      child: ConfigGridContentFrame(
        child: Column(
          children: [
            if (state.searching) _search(context, controller),
            Expanded(child: _configList(context, controller, state)),
          ],
        ),
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
    return ConfigGridList(
      rows: state.configs,
      emptyMessage: state.query.isEmpty
          ? AppLocalizations.of(context)!.homeOutboundViewNoOutbound
          : AppLocalizations.of(context)!.listNoSearchResult,
      emptyIcon: state.query.isEmpty ? Icons.data_object : Icons.search_off,
      onPingSubscription: (_) => controller.ping(),
      onRefresh: () => controller.refreshData(),
      onCleanSubscription: (_) => controller.cleanUnreachable(),
      subscriptionExpandable: false,
    );
  }
}
