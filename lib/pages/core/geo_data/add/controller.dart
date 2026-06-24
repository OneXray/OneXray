import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/geo_data/enum.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/validator.dart';

class GeoDatAddState {
  final GeoDataType type;

  const GeoDatAddState({required this.type});

  factory GeoDatAddState.initial() =>
      const GeoDatAddState(type: GeoDataType.domain);

  GeoDatAddState copyWith({GeoDataType? type}) {
    return GeoDatAddState(type: type ?? this.type);
  }
}

class GeoDatAddController extends Cubit<GeoDatAddState> {
  GeoDatAddController() : super(GeoDatAddState.initial());

  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Future<void> close() {
    nameController.dispose();
    urlController.dispose();
    return super.close();
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
}
