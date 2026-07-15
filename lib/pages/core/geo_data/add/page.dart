import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/geo_data/add/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GeoDatAddPage extends StatelessWidget {
  const GeoDatAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeoDatAddController(),
      child: BlocBuilder<GeoDatAddController, GeoDatAddPageState>(
        builder: (context, state) {
          final controller = context.read<GeoDatAddController>();
          return BlocBuilder<AppEventBus, AppEventBusState>(
            bloc: AppEventBus.instance,
            builder: (context, eventState) {
              final localizations = AppLocalizations.of(context)!;
              return SettingsPageScaffold(
                title: localizations.geoDatAddPageTitle,
                saveLabel: localizations.buttonAdd,
                saveLoading: eventState.downloading,
                onSave: eventState.downloading
                    ? null
                    : () => controller.save(context),
                body: _body(context, controller, state),
              );
            },
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddPageState state,
  ) {
    return SettingsPageScroll(
      desktopMaxWidth: 920,
      child: _section(context, controller, state),
    );
  }

  Widget _section(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddPageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.geoDatAddPageSection,
      children: [
        _name(context, controller),
        _type(context, controller, state),
        _url(context, controller),
        _autoUpdate(context, controller, state),
      ],
    );
  }

  Widget _name(BuildContext context, GeoDatAddController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.geoDatAddPageName,
      leading: const Icon(LucideIcons.tag),
      hintText: AppLocalizations.of(context)!.geoDatAddPageName,
    );
  }

  Widget _type(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddPageState state,
  ) {
    return SelectSettingRow<GeoDataType>(
      title: AppLocalizations.of(context)!.geoDatAddPageType,
      leading: const Icon(LucideIcons.listFilter),
      value: state.type.name,
      selections: GeoDataType.values,
      onSelected: (value) => controller.updateType(value),
    );
  }

  Widget _url(BuildContext context, GeoDatAddController controller) {
    return TextFieldSettingRow(
      controller: controller.urlController,
      label: AppLocalizations.of(context)!.geoDatAddPageUrl,
      leading: const Icon(LucideIcons.link),
      hintText: AppLocalizations.of(context)!.geoDatAddPageUrlExample,
      helperText: AppLocalizations.of(context)!.helpURL,
    );
  }

  Widget _autoUpdate(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final autoUpdate = state.autoUpdateState;
    final value = autoUpdate.geoDataEnable
        ? "${localizations.autoUpdatePageEnabled} · ${autoUpdate.geoDataInterval}"
        : localizations.autoUpdatePageDisabled;
    return SettingRow(
      title: localizations.autoUpdatePageTitle,
      value: value,
      leading: const Icon(LucideIcons.refreshCw),
      onTap: () => controller.gotoAutoUpdate(context),
      showChevron: true,
    );
  }
}
