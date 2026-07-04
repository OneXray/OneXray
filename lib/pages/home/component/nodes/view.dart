import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/nodes/controller.dart';
import 'package:onexray/pages/home/widget/config_grid_list.dart';
import 'package:onexray/pages/widget/data_list.dart';

class HomeNodeView extends StatefulWidget {
  const HomeNodeView({
    super.key,
    required this.queryType,
    required this.showSearch,
    required this.onSelect,
    this.selectedId,
  });

  final HomeNodeQueryType queryType;
  final bool showSearch;
  final int? selectedId;
  final ValueChanged<CoreConfigData> onSelect;

  @override
  State<HomeNodeView> createState() => _HomeNodeViewState();
}

class _HomeNodeViewState extends State<HomeNodeView> {
  late HomeNodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeNodeController(queryType: widget.queryType);
  }

  @override
  void didUpdateWidget(covariant HomeNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryType != widget.queryType) {
      final oldController = _controller;
      _controller = HomeNodeController(queryType: widget.queryType);
      oldController.close();
      return;
    }
    if (oldWidget.showSearch && !widget.showSearch) {
      _controller.clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _controller,
      child: BlocBuilder<HomeNodeController, HomeNodeViewState>(
        builder: (context, state) {
          final controller = context.read<HomeNodeController>();
          return _body(context, controller, state);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    HomeNodeController controller,
    HomeNodeViewState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ConfigGridContentFrame(
        child: Column(
          children: [
            if (widget.showSearch) _search(context, controller),
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

  Widget _configList(
    BuildContext context,
    HomeNodeController controller,
    HomeNodeViewState state,
  ) {
    return ConfigGridList(
      rows: state.configs,
      selectedId: widget.selectedId,
      onSelect: widget.onSelect,
      emptyMessage: state.query.isEmpty
          ? AppLocalizations.of(context)!.homeOutboundViewNoOutbound
          : AppLocalizations.of(context)!.listNoSearchResult,
      emptyIcon: state.query.isEmpty ? Icons.hub_outlined : Icons.search_off,
      onPingSubscription: (subId) => controller.ping(subId),
      onRefresh: () => controller.refreshData(),
      onCleanSubscription: (subId) => controller.cleanUnreachable(subId),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
