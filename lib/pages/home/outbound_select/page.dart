import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/component/config_row/view.dart';
import 'package:onexray/pages/home/outbound_select/controller.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/pages/widget/data_list.dart';

class OutboundSelectPage extends StatelessWidget {
  final OutboundSelectParams params;

  const OutboundSelectPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundSelectController(),
      child: BlocBuilder<OutboundSelectController, OutboundSelectState>(
        builder: (context, state) {
          final controller = context.read<OutboundSelectController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(
                AppLocalizations.of(context)!.outboundSelectPageTitle,
              ),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OutboundSelectController controller,
    OutboundSelectState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          if (state.configs.isNotEmpty || state.query.isNotEmpty)
            _search(context, controller),
          Expanded(child: _configList(context, controller, state)),
        ],
      ),
    );
  }

  Widget _search(BuildContext context, OutboundSelectController controller) {
    return ListSearchField(
      controller: controller.searchController,
      hintText: AppLocalizations.of(context)!.listSearchHint,
      onChanged: (value) => controller.updateSearchQuery(value),
    );
  }

  Widget _configList(
    BuildContext context,
    OutboundSelectController controller,
    OutboundSelectState state,
  ) {
    if (state.configs.isEmpty) {
      return ListEmptyView(
        message: AppLocalizations.of(context)!.homeOutboundViewNoOutbound,
      );
    }
    return ListView.separated(
      itemBuilder: (context, index) {
        final config = state.configs[index];
        final status = config.id == params.selectedId
            ? ConfigRowStatus.selected
            : ConfigRowStatus.unselected;
        return ConfigRowView(
          data: config,
          status: status,
          moreMenus: const [],
          tapCallback: () => controller.select(context, config),
        );
      },
      separatorBuilder: (_, _) => const Divider(),
      itemCount: state.configs.length,
    );
  }
}
