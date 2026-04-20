import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/component/config_row/enum.dart';
import 'package:onexray/pages/home/component/config_row/controller.dart';
import 'package:onexray/pages/theme/color.dart';
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
    return _body(context, _controller);
  }

  Widget _body(BuildContext context, ConfigRowController controller) {
    if (tapCallback != null) {
      return InkWell(
        onTap: () => tapCallback!(),
        child: _content(context, controller),
      );
    } else {
      return _content(context, controller);
    }
  }

  Widget _content(BuildContext context, ConfigRowController controller) {
    Color color;
    switch (status) {
      case ConfigRowStatus.unselected:
        color = ColorManager.surface(context);
        break;
      case ConfigRowStatus.selected:
        color = ColorManager.selected(context);
        break;
      case ConfigRowStatus.running:
        color = ColorManager.running(context);
        break;
    }
    final tags = data.readTags(context).map((e) => TagView(tag: e)).toList();
    return Container(
      padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
      color: color,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: ColorManager.primaryText(context),
                  ),
                ),
                if (tags.isNotEmpty) Row(children: tags),
              ],
            ),
          ),
          if (moreMenus.isNotEmpty)
            IconMenuPicker(
              icon: Icons.more_vert,
              menus: moreMenus,
              callback: (menuId) =>
                  controller.moreAction(context, data, menuId),
            ),
        ],
      ),
    );
  }
}
