import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/app_icon/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';

class AppIconPage extends StatelessWidget {
  const AppIconPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppIconController(),
      child: BlocBuilder<AppIconController, AppIconState>(
        builder: (context, state) {
          final controller = context.read<AppIconController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.appIconPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppIconState state,
    AppIconController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          _selectedIcon(context, state),
          Expanded(child: _icons(context, controller)),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _selectedIcon(BuildContext context, AppIconState state) {
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(AppLocalizations.of(context)!.appIconPageSelect),
          ),
          _image(state.appIcon.assetImage),
        ],
      ),
    );
  }

  Widget _icons(BuildContext context, AppIconController controller) {
    final icons = AppIcon.values;
    return GridView.builder(
      itemCount: icons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemBuilder: (_, int index) => InkWell(
        onTap: () => controller.updateIcon(icons[index]),
        child: _image(icons[index].assetImage),
      ),
    );
  }

  Widget _image(AssetGenImage image) {
    return Container(
      constraints: BoxConstraints(minHeight: 60, maxHeight: 256),
      padding: EdgeInsetsDirectional.all(15),
      child: image.image(),
    );
  }

  Widget _bottomButton(BuildContext context, AppIconController controller) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.buttonSave,
              callback: () => controller.save(context),
            ),
          ),
        ],
      ),
    );
  }
}
