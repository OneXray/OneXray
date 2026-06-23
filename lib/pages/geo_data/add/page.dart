import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/geo_data/add/controller.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/geo_data/enum.dart';

class GeoDatAddPage extends StatelessWidget {
  const GeoDatAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeoDatAddController(),
      child: BlocBuilder<GeoDatAddController, GeoDatAddState>(
        builder: (context, state) {
          final controller = context.read<GeoDatAddController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.geoDatAddPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _section(context, controller, state),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.geoDatAddPageSection,
      children: [
        _name(context, controller),
        _type(context, controller, state),
        _url(context, controller),
        _autoUpdate(context),
      ],
    );
  }

  Widget _name(BuildContext context, GeoDatAddController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.geoDatAddPageName,
      hintText: AppLocalizations.of(context)!.geoDatAddPageName,
    );
  }

  Widget _type(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddState state,
  ) {
    return SelectSettingRow<GeoDataType>(
      title: AppLocalizations.of(context)!.geoDatAddPageType,
      value: state.type.name,
      selections: GeoDataType.values,
      onSelected: (value) => controller.updateType(value),
    );
  }

  Widget _url(BuildContext context, GeoDatAddController controller) {
    return TextFieldSettingRow(
      controller: controller.urlController,
      label: AppLocalizations.of(context)!.geoDatAddPageUrl,
      hintText: AppLocalizations.of(context)!.geoDatAddPageUrlExample,
      helperText: AppLocalizations.of(context)!.helpURL,
    );
  }

  Widget _autoUpdate(BuildContext context) {
    return SettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageTitle,
      onTap: () => context.push(RouterPath.autoUpdate),
      showChevron: true,
    );
  }

  Widget _bottomButton(BuildContext context, GeoDatAddController controller) {
    return BottomView(
      child: Row(
        children: [
          BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, state) =>
                _saveButton(context, controller, state),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(
    BuildContext context,
    GeoDatAddController controller,
    AppEventBusState state,
  ) {
    if (state.downloading) {
      return const CircularProgressIndicator();
    } else {
      return Expanded(
        child: PrimaryBottomButton(
          title: AppLocalizations.of(context)!.buttonAdd,
          callback: () => controller.save(context),
        ),
      );
    }
  }
}
