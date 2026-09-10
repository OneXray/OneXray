import 'package:onexray/service/shared/failure.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/shared/event_bus/enum.dart';
import 'package:onexray/service/shared/event_bus/service.dart';

class ThemePageState {
  final ThemeCode themeCode;

  const ThemePageState({this.themeCode = ThemeCode.system});

  ThemePageState copyWith({ThemeCode? themeCode}) {
    return ThemePageState(themeCode: themeCode ?? this.themeCode);
  }
}

class ThemeController extends PageCubit<ThemePageState> {
  ThemeController() : super(const ThemePageState()) {
    _readData();
  }

  Future<void> _readData() async {
    final eventBus = AppEventBus.instance;
    emit(state.copyWith(themeCode: eventBus.state.themeCode));
  }

  void updateThemeCode(ThemeCode? value) {
    if (value != null) {
      emit(state.copyWith(themeCode: value));
    }
  }

  Future<void> save(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    try {
      await AppEventBus.instance.updateThemeCode(state.themeCode);
      if (context.mounted) {
        ContextAlert.showToast(context, l.prototypeSettingsSaved);
        if (ModalRoute.of(context)?.isCurrent == true) context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          appFailureMessage(l, error, operation: l.buttonSaveFailed),
        );
      }
    }
  }
}
