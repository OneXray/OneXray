import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
}

class AppIconState {
  final AppIcon appIcon;

  const AppIconState({this.appIcon = AppIcon.primary});

  AppIconState copyWith({AppIcon? appIcon}) {
    return AppIconState(appIcon: appIcon ?? this.appIcon);
  }
}

class AppIconController extends Cubit<AppIconState> {
  AppIconController() : super(const AppIconState()) {
    _readCurrentIcon();
  }

  Future<void> _readCurrentIcon() async {
    final currentIcon = await AppHostApi().getCurrentAppIcon();
    if (currentIcon.isNotEmpty) {
      final appIcon = AppIcon.fromString(currentIcon);
      if (appIcon != null) {
        emit(state.copyWith(appIcon: appIcon));
      }
    }
  }

  void updateIcon(AppIcon value) {
    emit(state.copyWith(appIcon: value));
  }

  Future<void> save(BuildContext context) async {
    var name = state.appIcon.name;
    if (state.appIcon == AppIcon.primary) {
      name = "";
    }
    final res = await AppHostApi().setAppIcon(name);
    if (context.mounted) {
      if (res) {
        context.pop();
      } else {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.appIconPageSetFailed,
        );
      }
    }
  }
}
