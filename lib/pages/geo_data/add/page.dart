import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/geo_data/add/controller.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
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
    );
  }

  Widget _section(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.geoDatAddPageSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _name(context, controller),
          _type(context, controller, state),
          _url(context, controller),
        ],
      ),
    );
  }

  Widget _name(BuildContext context, GeoDatAddController controller) {
    return TextField(
      controller: controller.nameController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.geoDatAddPageName),
        hintText: AppLocalizations.of(context)!.geoDatAddPageName,
      ),
    );
  }

  Widget _type(
    BuildContext context,
    GeoDatAddController controller,
    GeoDatAddState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.geoDatAddPageType),
        TextMenuPicker<GeoDataType>(
          title: state.type.name,
          selections: GeoDataType.values,
          callback: (value) => controller.updateType(value),
        ),
      ],
    );
  }

  Widget _url(BuildContext context, GeoDatAddController controller) {
    return TextField(
      controller: controller.urlController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.geoDatAddPageUrl),
        hintText: AppLocalizations.of(context)!.geoDatAddPageUrlExample,
        helperText: AppLocalizations.of(context)!.helpURL,
      ),
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
