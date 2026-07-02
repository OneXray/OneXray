import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/home/component/nodes/controller.dart';
import 'package:onexray/pages/home/widget/config_grid_list.dart';
import 'package:onexray/pages/widget/data_list.dart';

class HomeNodeView extends StatelessWidget {
  const HomeNodeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeNodeController, HomeNodeState>(
      builder: (context, state) {
        final controller = context.read<HomeNodeController>();
        return _body(context, controller, state);
      },
    );
  }

  Widget _body(
    BuildContext context,
    HomeNodeController controller,
    HomeNodeState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ConfigGridContentFrame(
        child: Column(
          children: [
            _xraySetting(context, controller, state),
            const Divider(),
            if (state.searching) _search(context, controller),
            Expanded(child: _configList(context, controller, state)),
          ],
        ),
      ),
    );
  }

  Widget _search(BuildContext context, HomeNodeController controller) {
    return ListSearchField(
      controller: controller.searchController,
      hintText: AppLocalizations.of(context)!.listSearchHint,
      onChanged: (value) => controller.updateSearchQuery(value),
    );
  }

  Widget _xraySetting(
    BuildContext context,
    HomeNodeController controller,
    HomeNodeState state,
  ) {
    return DataListRow(
      title: AppLocalizations.of(context)!.homeOutboundViewXraySetting,
      subtitle: state.xraySettingName,
      verticalPadding: ConfigGridList.compactRowVerticalPadding,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => controller.gotoXraySetting(context),
    );
  }

  Widget _configList(
    BuildContext context,
    HomeNodeController controller,
    HomeNodeState state,
  ) {
    return ConfigGridList(
      rows: state.configs,
      emptyMessage: state.query.isEmpty
          ? AppLocalizations.of(context)!.homeOutboundViewNoOutbound
          : AppLocalizations.of(context)!.listNoSearchResult,
      emptyIcon: state.query.isEmpty ? Icons.hub_outlined : Icons.search_off,
      onPingSubscription: (subId) => controller.ping(subId),
      onRefresh: () => controller.refreshData(),
      onCleanSubscription: (subId) => controller.cleanUnreachable(subId),
    );
  }
}
