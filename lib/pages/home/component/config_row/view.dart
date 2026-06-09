import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/component/config_row/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/db/config_reader.dart';

class ConfigRowView extends StatelessWidget {
  final CoreConfigData data;
  final ConfigRowStatus status;
  final List<IconMenuId> moreMenus;
  final VoidCallback? tapCallback;

  const ConfigRowView({
    super.key,
    required this.data,
    required this.status,
    required this.moreMenus,
    required this.tapCallback,
  });

  static final _controller = ConfigRowController();

  @override
  Widget build(BuildContext context) {
    return _content(context, _controller);
  }

  Widget _content(BuildContext context, ConfigRowController controller) {
    final tags = data.readTags(context).map((e) => TagView(tag: e)).toList();
    return DataListRow(
      title: data.name,
      tags: tags,
      tone: _tone,
      onTap: tapCallback,
      trailing: moreMenus.isEmpty
          ? null
          : IconMenuPicker(
              icon: Icons.more_vert,
              menus: moreMenus,
              callback: (menuId) =>
                  controller.moreAction(context, data, menuId),
            ),
    );
  }

  DataListRowTone get _tone {
    switch (status) {
      case ConfigRowStatus.unselected:
        return DataListRowTone.normal;
      case ConfigRowStatus.selected:
        return DataListRowTone.selected;
      case ConfigRowStatus.running:
        return DataListRowTone.running;
    }
  }
}
