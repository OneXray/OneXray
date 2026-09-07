import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/service/launch/setup.dart';

enum SetupAction {
  acceptPrivacy,
  privacy,
  back,
  permission,
  chooseInterface,
  continueSystem,
  chooseRegion,
  continueRegion,
  skipRegion,
  finish,
  retry,
}

class SetupPageState {
  final SetupStep step;
  final bool busy;
  final SetupAction? activeAction;
  final ServerImportAction? activeImport;
  final bool localReady;
  final bool hasServers;
  final PlatformPermissionResult? permission;
  final String interfaceName;
  final String region;
  final List<String> regionCodes;
  final SetupFailure? failure;

  const SetupPageState({
    this.step = SetupStep.welcome,
    this.busy = true,
    this.activeAction,
    this.activeImport,
    this.localReady = false,
    this.hasServers = false,
    this.permission,
    this.interfaceName = '',
    this.region = '',
    this.regionCodes = const [],
    this.failure,
  });

  bool get authorized =>
      permission != null && SetupService.permissionReady(permission!);

  bool ready({required bool requiresInterface}) =>
      localReady &&
      authorized &&
      (!requiresInterface || interfaceName.isNotEmpty);

  SetupPageState copyWith({
    SetupStep? step,
    bool? busy,
    SetupAction? activeAction,
    ServerImportAction? activeImport,
    bool clearAction = false,
    bool? localReady,
    bool? hasServers,
    PlatformPermissionResult? permission,
    String? interfaceName,
    String? region,
    List<String>? regionCodes,
    SetupFailure? failure,
    bool clearFailure = false,
  }) => SetupPageState(
    step: step ?? this.step,
    busy: busy ?? this.busy,
    activeAction: clearAction ? null : activeAction ?? this.activeAction,
    activeImport: clearAction ? null : activeImport ?? this.activeImport,
    localReady: localReady ?? this.localReady,
    hasServers: hasServers ?? this.hasServers,
    permission: permission ?? this.permission,
    interfaceName: interfaceName ?? this.interfaceName,
    region: region ?? this.region,
    regionCodes: regionCodes ?? this.regionCodes,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

class SetupController extends PageCubit<SetupPageState>
    with WidgetsBindingObserver {
  final SetupService service;
  StreamSubscription<bool>? _serversSubscription;

  SetupController({SetupService? service})
    : service = service ?? SetupService(),
      super(const SetupPageState()) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      _perform(() async {
        emit(state.copyWith(step: await this.service.currentStep()));
        await _load();
      }, initial: true),
    );
  }

  void handleAction(BuildContext context, SetupAction action) {
    if (action == SetupAction.privacy) {
      unawaited(context.push('${RouterPath.setup}/privacy'));
      return;
    }
    if (action == SetupAction.back) {
      showWelcome();
      return;
    }
    if (state.busy) return;
    emit(state.copyWith(activeAction: action));
    switch (action) {
      case SetupAction.acceptPrivacy:
        unawaited(acceptPrivacy());
      case SetupAction.privacy:
        unawaited(context.push('${RouterPath.setup}/privacy'));
      case SetupAction.back:
        showWelcome();
      case SetupAction.permission:
        unawaited(requestPermission());
      case SetupAction.chooseInterface:
        unawaited(chooseInterface(context));
      case SetupAction.continueSystem:
        unawaited(continueSystem());
      case SetupAction.chooseRegion:
        unawaited(chooseRegion(context));
      case SetupAction.continueRegion:
        unawaited(continueRegion());
      case SetupAction.skipRegion:
        unawaited(skipRegion());
      case SetupAction.finish:
        unawaited(finish());
      case SetupAction.retry:
        unawaited(retry());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        this.state.step == SetupStep.system &&
        !this.state.busy) {
      unawaited(retry());
    }
  }

  Future<void> _load() async {
    final step = state.step;
    if (step == SetupStep.welcome || step == SetupStep.complete) return;
    try {
      await service.prepareLocal();
    } catch (_) {
      throw const SetupFailure('local');
    }
    final configuration = await service.configuration();
    final codes = await service.regionCodes();
    emit(
      state.copyWith(
        localReady: true,
        interfaceName: state.interfaceName.isEmpty
            ? configuration.policy.xrayOutboundInterfaceName
            : state.interfaceName,
        regionCodes: codes,
      ),
    );
    final permission = await service.checkPermission();
    emit(state.copyWith(permission: permission));
    if (!state.authorized ||
        (service.requiresInterface && state.interfaceName.isEmpty)) {
      emit(state.copyWith(step: SetupStep.system));
      return;
    }
    if (state.step == SetupStep.region && !codes.contains(state.region)) {
      final region = await service.suggestRegion();
      if (region != null && codes.contains(region)) {
        emit(state.copyWith(region: region));
      }
    }
    if (state.step == SetupStep.servers) await _watchServers();
  }

  Future<void> retry() => _perform(_load);

  void showWelcome() =>
      emit(state.copyWith(step: SetupStep.welcome, clearFailure: true));

  Future<void> acceptPrivacy() => _perform(() async {
    await service.acceptPrivacy();
    emit(state.copyWith(step: SetupStep.system, clearAction: true));
    await _load();
  });

  Future<void> requestPermission() => _perform(() async {
    await service.prepareLocal();
    emit(state.copyWith(localReady: true));
    final permission = await service.checkPermission(request: true);
    emit(state.copyWith(permission: permission));
    if (!SetupService.permissionReady(permission)) {
      throw SetupFailure('permission', permission: permission);
    }
    await _load();
  });

  Future<void> skipRegion() => _perform(() async {
    await service.continueRegion(null);
    emit(state.copyWith(step: SetupStep.servers, clearAction: true));
    await _load();
  });

  Future<void> continueSystem() => _perform(() async {
    await service.continueSystem(state.interfaceName);
    emit(state.copyWith(step: SetupStep.region, clearAction: true));
    await _load();
  });

  Future<void> continueRegion() => _perform(() async {
    await service.continueRegion(state.region);
    emit(state.copyWith(step: SetupStep.servers, clearAction: true));
    await _load();
  });

  Future<void> chooseInterface(BuildContext context) => _perform(() async {
    final options = await service.interfaces();
    if (!context.mounted) return;
    final name = await context.push<String>(
      '${RouterPath.setup}/interface',
      extra: SetupInterfaceParams(options, state.interfaceName),
    );
    if (name != null) emit(state.copyWith(interfaceName: name));
  });

  Future<void> chooseRegion(BuildContext context) => _perform(() async {
    final code = await context.push<String>(
      '${RouterPath.setup}/region',
      extra: SetupRegionParams(state.regionCodes, state.region),
    );
    if (code != null) {
      emit(state.copyWith(region: code));
    }
  });

  Future<void> addServers(
    BuildContext context,
    ServerImportAction action,
    Future<void> Function(BuildContext, ServerImportAction) open,
  ) => _perform(() async {
    emit(state.copyWith(activeImport: action));
    await open(context, action);
  });

  Future<void> _watchServers() async {
    if (_serversSubscription != null || !isPageActive) return;
    final first = Completer<void>();
    _serversSubscription = service.watchHasServers().listen(
      (hasServers) {
        emit(state.copyWith(hasServers: hasServers));
        if (!first.isCompleted) {
          first.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_serversSubscription?.cancel());
        _serversSubscription = null;
        if (!first.isCompleted) {
          first.completeError(error, stackTrace);
        }
        emit(
          state.copyWith(
            step: SetupStep.system,
            localReady: false,
            hasServers: false,
            failure: const SetupFailure('local'),
          ),
        );
      },
    );
    await first.future;
  }

  Future<void> finish() => _perform(_finish);

  Future<void> _finish() async {
    await service.finish();
    emit(state.copyWith(step: SetupStep.complete));
  }

  void goConnect(BuildContext context) => context.go(RouterPath.connect);

  String failureText(AppLocalizations l10n) =>
      switch (state.failure?.component) {
        'permission' =>
          state.permission?.kind == PlatformPermissionKind.androidLocalNetwork
              ? l10n.prototypePermissionNotGranted
              : l10n.prototypeVpnPermissionRequired,
        'interface' => l10n.prototypeChooseInterfaceNotice,
        'region' => l10n.prototypeCheckNetwork,
        _ => l10n.prototypeTemporarilyUnavailable,
      };

  Future<void> _perform(
    Future<void> Function() action, {
    bool initial = false,
  }) async {
    if (state.busy && !initial) return;
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      await action();
    } catch (error) {
      final failure = error is SetupFailure
          ? error
          : const SetupFailure('system');
      final step = await service.currentStep();
      emit(
        state.copyWith(
          failure: failure,
          permission: failure.permission,
          step: switch (failure.component) {
            'local' ||
            'system' ||
            'permission' ||
            'interface' => SetupStep.system,
            _ => step == SetupStep.complete ? state.step : step,
          },
        ),
      );
    } finally {
      emit(state.copyWith(busy: false, clearAction: true));
    }
  }

  @override
  Future<void> disposePageResources() async {
    WidgetsBinding.instance.removeObserver(this);
    await _serversSubscription?.cancel();
  }
}
