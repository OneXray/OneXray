import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/main/actions.dart';
import 'package:onexray/pages/home/main/state.dart';
import 'package:onexray/pages/home/main/system_extension_coordinator.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/background_task/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/geo_data/system_dat_service.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

class HomeController extends Cubit<HomePageState> {
  final BuildContext context;

  HomeController(this.context)
    : super(
        HomePageState.initial(
          xrayProfileId: AppEventBus.instance.state.xrayProfileId,
        ),
      ) {
    _asyncInit();
  }

  late final StreamSubscription<void> _toastSubscription;
  StreamSubscription<int>? _xrayProfileSubscription;
  Future<void>? _systemGeoDatFuture;
  late final _actions = HomeActions(context);
  late final _systemExtension = HomeSystemExtensionCoordinator(
    context: context,
    refreshVpnStatus: _refreshVpnStatus,
  );

  Future<void> _asyncInit() async {
    _initToastStream();
    _systemExtension.start();
    unawaited(_listenXrayProfile());
    _systemGeoDatFuture = _checkSystemGeoDatAssets();
    unawaited(_systemGeoDatFuture!);
    unawaited(_initServices());
    try {
      final id = await PreferencesKey().readLastConfigId();
      if (isClosed) {
        return;
      }
      emit(state.copyWith(configId: id));
      await _updateConfigName(id);
    } catch (e, stackTrace) {
      ygReportError(e, stackTrace, reason: 'Home initialization failed');
    }
    unawaited(_checkAppUpdate());
  }

  Future<void> _initServices() async {
    try {
      if (isClosed || !context.mounted) {
        return;
      }
      await context.read<AppEventBus>().asyncInitService(context);
    } catch (e, stackTrace) {
      ygReportError(
        e,
        stackTrace,
        reason: 'Home service initialization failed',
      );
    }

    if (isClosed) {
      return;
    }
    try {
      BackgroundTaskService().init();
    } catch (e, stackTrace) {
      ygReportError(
        e,
        stackTrace,
        reason: 'Background task initialization failed',
      );
    }
    unawaited(_refreshVpnStatus());
  }

  Future<void> _refreshVpnStatus() async {
    try {
      await VpnService().refreshVpnStatus();
    } catch (e, stackTrace) {
      ygReportError(e, stackTrace, reason: 'VPN status refresh failed');
    }
  }

  Future<void> _checkSystemGeoDatAssets() async {
    try {
      await SystemGeoDatService().checkAssets();
    } catch (e, stackTrace) {
      ygReportError(e, stackTrace, reason: 'System GeoData check failed');
    }
  }

  Future<void> _ensureSystemGeoDatAssets() async {
    final systemGeoDatFuture = _systemGeoDatFuture ??=
        _checkSystemGeoDatAssets();
    await systemGeoDatFuture;
  }

  Future<void> _checkAppUpdate() async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (isClosed || !context.mounted) {
        return;
      }
      if (!await PreferencesKey().readPrivacyAccepted()) {
        return;
      }
      final service = AppUpdateService();
      if (!await service.shouldRunAutomaticCheck()) {
        return;
      }
      await service.recordAutomaticCheck();
      final result = await service.checkForUpdate();
      if (isClosed ||
          !context.mounted ||
          result.status != AppUpdateCheckStatus.available ||
          result.updateInfo == null) {
        return;
      }
      final updateInfo = result.updateInfo!;
      if (!await service.shouldShowAutomaticReminder(updateInfo)) {
        return;
      }
      if (!isClosed && context.mounted) {
        await context.pushAppUpdateDialog(updateInfo);
      }
    } catch (e, stackTrace) {
      ygReportError(e, stackTrace, reason: 'Automatic update check failed');
    }
  }

  void _initToastStream() {
    _toastSubscription = ToastService().toastBroadcast.stream.listen(
      (message) => _showToast(message),
    );
  }

  void _showToast(String message) {
    if (context.mounted) {
      ContextAlert.showToast(context, message);
    }
  }

  Future<void> _listenXrayProfile() async {
    final eventBus = AppEventBus.instance;
    var xrayProfileId = eventBus.state.xrayProfileId;
    xrayProfileId = await PreferencesKey().readXrayProfileId();
    if (isClosed) {
      return;
    }
    await _readXrayProfile(xrayProfileId);

    _xrayProfileSubscription = eventBus.stream
        .map((s) => s.xrayProfileId)
        .distinct()
        .listen((data) => _readXrayProfile(data));
  }

  Future<void> _readXrayProfile(int id) async {
    if (isClosed) {
      return;
    }
    switch (id) {
      case DBConstants.defaultId:
        emit(
          state.copyWith(
            xrayProfileName:
                appLocalizationsNoContext().xrayProfileListPageSimple,
          ),
        );
        break;
      case XrayProfileSimple.simpleId:
        emit(
          state.copyWith(
            xrayProfileName:
                appLocalizationsNoContext().xrayProfileListPageSimple,
          ),
        );
        break;
      default:
        final xrayProfileData = await AppDatabase().coreConfigDao.searchRow(id);
        if (isClosed) {
          return;
        }
        if (xrayProfileData != null) {
          emit(state.copyWith(xrayProfileName: xrayProfileData.name));
        } else {
          emit(
            state.copyWith(
              xrayProfileName:
                  appLocalizationsNoContext().xrayProfileListPageSimple,
            ),
          );
        }
        break;
    }
  }

  HomeConnectionViewPageState buildConnectionViewState(
    BuildContext context,
    HomePageState homeState,
    AppEventBusState eventState,
  ) {
    return HomeConnectionViewStateBuilder.build(context, homeState, eventState);
  }

  void gotoNodeInfo() => _actions.gotoNodeInfo();

  void gotoXrayProfile() => _actions.gotoXrayProfile();

  Future<void> addMenuAction(HomeAddMenuAction action) {
    return _actions.addMenuAction(action);
  }

  Future<void> _updateConfigName(int value) async {
    final configName = await _readConfigName(value);
    if (!isClosed && state.configId == value) {
      emit(state.copyWith(configName: configName));
    }
  }

  Future<String> _readConfigName(int id) async {
    if (id == DBConstants.defaultId) {
      return "";
    }
    final config = await AppDatabase().coreConfigDao.searchRow(id);
    return config?.name ?? "";
  }

  void updateConfigId(int value) {
    emit(state.copyWith(configId: value, configName: ""));
    unawaited(_updateConfigName(value));
  }

  void toggleNodeSearch() {
    emit(state.copyWith(nodeSearchVisible: !state.nodeSearchVisible));
  }

  Future<void> startVpn() async {
    if (state.vpnCommandLoading || AppEventBus.instance.state.vpnLoading) {
      return;
    }
    if (state.configId == DBConstants.defaultId) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.vpnSelectOneConfig,
      );
      return;
    }

    emit(state.copyWith(vpnCommandLoading: true));
    try {
      await _ensureSystemGeoDatAssets();
      final result = await VpnService().startVpn(state.configId);
      await _handleVpnCommandResult(result);
    } finally {
      if (!isClosed) {
        emit(state.copyWith(vpnCommandLoading: false));
      }
    }
  }

  Future<void> _handleVpnCommandResult(NativeVpnCommandResult result) async {
    if (!context.mounted) {
      return;
    }
    switch (result.state) {
      case NativeVpnCommandState.success:
        return;
      case NativeVpnCommandState.waitingForPlatformPermission:
        final permission = result.permission;
        if (await _systemExtension.handleStartPermission(permission)) {
          return;
        }
        if (!context.mounted) {
          return;
        }
        if (permission?.kind == PlatformPermissionKind.androidVpn &&
            permission?.state == PlatformPermissionState.denied) {
          await ContextAlert.showPermissionDialog(context);
        }
        return;
      case NativeVpnCommandState.failed:
        final message = result.message;
        if (message != null && message.isNotEmpty) {
          ContextAlert.showToast(context, message);
        }
        return;
    }
  }

  @override
  Future<void> close() async {
    await _toastSubscription.cancel();
    await _xrayProfileSubscription?.cancel();
    await _systemExtension.close();
    return super.close();
  }
}
