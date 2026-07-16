import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/validator.dart';

class GeoDatAddPageState {
  final GeoDataType type;
  final AutoUpdateState autoUpdateState;

  const GeoDatAddPageState({required this.type, required this.autoUpdateState});

  factory GeoDatAddPageState.initial() => GeoDatAddPageState(
    type: GeoDataType.domain,
    autoUpdateState: AutoUpdateState(),
  );

  GeoDatAddPageState copyWith({
    GeoDataType? type,
    AutoUpdateState? autoUpdateState,
  }) {
    return GeoDatAddPageState(
      type: type ?? this.type,
      autoUpdateState: autoUpdateState ?? this.autoUpdateState,
    );
  }
}

class GeoDatAddController extends PageCubit<GeoDatAddPageState> {
  GeoDatAddController() : super(GeoDatAddPageState.initial()) {
    _readAutoUpdateState();
  }

  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
    urlController.dispose();
  }

  Future<void> updateType(GeoDataType value) async {
    emit(state.copyWith(type: value));
  }

  Future<void> save(BuildContext context) async {
    final name = nameController.text.removeWhitespace;
    final url = urlController.text.removeWhitespace;
    final check = await GeoDataValidator.validate(name, url);
    if (check.item1) {
      final success = await GeoDataService().insertGeoDat(
        name,
        state.type,
        url,
      );
      if (context.mounted) {
        if (success) {
          context.pop();
        } else {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.buttonAddFailed,
          );
        }
      }
    } else {
      if (context.mounted) {
        ContextAlert.showToast(context, check.item2);
      }
    }
  }

  Future<void> gotoAutoUpdate(BuildContext context) async {
    await context.pushScoped(AppSecondaryDestination.autoUpdate);
    await _readAutoUpdateState();
  }

  Future<void> _readAutoUpdateState() async {
    final autoUpdateState = AutoUpdateState();
    await autoUpdateState.readFromPreferences();
    if (isPageActive) {
      emit(state.copyWith(autoUpdateState: autoUpdateState));
    }
  }
}
