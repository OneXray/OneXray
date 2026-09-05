import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/mixin/alert.dart';

enum AppIcon {
  primary("IconBlue"),
  black("IconBlack"),
  green("IconGreen"),
  orange("IconOrange"),
  purple("IconPurple"),
  red("IconRed");

  const AppIcon(this.name);

  final String name;

  @override
  String toString() => name;

  static AppIcon? fromString(String name) {
    for (final value in AppIcon.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static List<String> get names {
    return AppIcon.values.map((e) => e.name).toList();
  }

  AssetGenImage get assetImage {
    switch (this) {
      case AppIcon.primary:
        return Assets.appIcon.blue;
      case AppIcon.black:
        return Assets.appIcon.black;
      case AppIcon.green:
        return Assets.appIcon.green;
      case AppIcon.orange:
        return Assets.appIcon.orange;
      case AppIcon.purple:
        return Assets.appIcon.purple;
      case AppIcon.red:
        return Assets.appIcon.red;
    }
  }

  AssetGenImage get dockAssetImage {
    switch (this) {
      case AppIcon.primary:
        return Assets.macosIcon.blue;
      case AppIcon.black:
        return Assets.macosIcon.black;
      case AppIcon.green:
        return Assets.macosIcon.green;
      case AppIcon.orange:
        return Assets.macosIcon.orange;
      case AppIcon.purple:
        return Assets.macosIcon.purple;
      case AppIcon.red:
        return Assets.macosIcon.red;
    }
  }
}

class AppIconPageState {
  final AppIcon appIcon;
  final bool loading;
  final bool saving;

  const AppIconPageState({
    this.appIcon = AppIcon.primary,
    this.loading = true,
    this.saving = false,
  });

  AppIconPageState copyWith({AppIcon? appIcon, bool? loading, bool? saving}) {
    return AppIconPageState(
      appIcon: appIcon ?? this.appIcon,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
    );
  }
}

class AppIconController extends PageCubit<AppIconPageState> {
  AppIconController() : super(const AppIconPageState()) {
    _readCurrentIcon();
  }

  Future<void> _readCurrentIcon() async {
    try {
      final currentIcon = await AppHostApi().getCurrentAppIcon();
      emit(
        state.copyWith(
          appIcon: AppIcon.fromString(currentIcon) ?? AppIcon.primary,
        ),
      );
    } catch (_) {
      // Keep the default preview if the optional native icon query fails.
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  void updateIcon(AppIcon value) {
    if (state.loading || state.saving) return;
    emit(state.copyWith(appIcon: value));
  }

  Future<void> save(BuildContext context) async {
    if (state.loading || state.saving) return;
    emit(state.copyWith(saving: true));
    var name = state.appIcon.name;
    if (state.appIcon == AppIcon.primary) {
      name = "";
    }
    try {
      if (!await AppHostApi().setAppIcon(name)) {
        throw StateError('Icon update failed');
      }
      if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
        context.pop();
      }
    } catch (_) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.appIconPageSetFailed,
        );
      }
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  void cancel(BuildContext context) {
    context.pop();
  }
}
