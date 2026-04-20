import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/component/config_row/view.dart';
import 'package:onexray/pages/home/home/controller.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';

/// A config row that reacts to selected and running state changes.
class SelectableConfigRow extends StatelessWidget {
  const SelectableConfigRow({super.key, required this.item});

  final ConfigItem item;

  @override
  Widget build(BuildContext context) {
    final data = item.config;
    final homeController = context.read<HomeController>();
    final selectedConfigId = context.select<HomeController, int>(
      (controller) => controller.state.configId,
    );
    final runningId = context.select<AppEventBus, int>(
      (eventBus) => eventBus.state.runningId,
    );
    final status = data.id == runningId
        ? ConfigRowStatus.running
        : data.id == selectedConfigId
        ? ConfigRowStatus.selected
        : ConfigRowStatus.unselected;
    return ConfigRowView(
      data: data,
      status: status,
      moreMenus: [
        IconMenuId.edit,
        IconMenuId.share,
        IconMenuId.copy,
        IconMenuId.delete,
      ],
      tapCallback: () => homeController.updateConfigId(context, data.id),
    );
  }
}
