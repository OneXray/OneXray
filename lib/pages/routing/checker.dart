import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/routing/checker.dart';
import 'package:onexray/service/routing/state.dart';

const _unchangedRouteCheckerValue = Object();

class RouteCheckerState {
  final ConnectionConfiguration configuration;
  final RoutingProfileState? customDraft;
  final String target;
  final String port;
  final String network;
  final RouteCheckOutcome? result;
  final bool busy;
  final bool failed;
  final int revision;
  final bool expanded;

  const RouteCheckerState({
    required this.configuration,
    this.customDraft,
    this.target = 'github.com',
    this.port = '443',
    this.network = 'tcp',
    this.result,
    this.busy = false,
    this.failed = false,
    this.revision = 0,
    this.expanded = false,
  });

  RouteCheckerState copyWith({
    ConnectionConfiguration? configuration,
    Object? customDraft = _unchangedRouteCheckerValue,
    String? target,
    String? port,
    String? network,
    Object? result = _unchangedRouteCheckerValue,
    bool? busy,
    bool? failed,
    int? revision,
    bool? expanded,
  }) => RouteCheckerState(
    configuration: configuration ?? this.configuration,
    customDraft: identical(customDraft, _unchangedRouteCheckerValue)
        ? this.customDraft
        : customDraft as RoutingProfileState?,
    target: target ?? this.target,
    port: port ?? this.port,
    network: network ?? this.network,
    result: identical(result, _unchangedRouteCheckerValue)
        ? this.result
        : result as RouteCheckOutcome?,
    busy: busy ?? this.busy,
    failed: failed ?? this.failed,
    revision: revision ?? this.revision,
    expanded: expanded ?? this.expanded,
  );
}

class RouteCheckerCubit extends PageCubit<RouteCheckerState> {
  final RouteCheckService service;
  final target = TextEditingController(text: 'github.com');
  final port = TextEditingController(text: '443');

  RouteCheckerCubit({
    required ConnectionConfiguration configuration,
    RoutingProfileState? customDraft,
    RouteCheckService? service,
  }) : service = service ?? RouteCheckService(),
       super(
         RouteCheckerState(
           configuration: configuration,
           customDraft: customDraft,
         ),
       ) {
    target.addListener(_targetChanged);
    port.addListener(_portChanged);
  }

  void updateConfiguration(
    ConnectionConfiguration configuration,
    RoutingProfileState? customDraft,
  ) {
    if (state.configuration.encode() == configuration.encode() &&
        state.customDraft?.encode() == customDraft?.encode()) {
      return;
    }
    emit(
      state.copyWith(
        configuration: configuration,
        customDraft: customDraft,
        result: null,
        failed: false,
        revision: state.revision + 1,
      ),
    );
  }

  void _targetChanged() {
    final value = target.text;
    if (state.target == value) return;
    emit(
      state.copyWith(
        target: value,
        result: null,
        failed: false,
        revision: state.revision + 1,
      ),
    );
  }

  void _portChanged() {
    final value = port.text;
    if (state.port == value) return;
    emit(
      state.copyWith(
        port: value,
        result: null,
        failed: false,
        revision: state.revision + 1,
      ),
    );
  }

  void updateNetwork(String value) {
    emit(
      state.copyWith(
        network: value,
        result: null,
        failed: false,
        revision: state.revision + 1,
      ),
    );
  }

  void toggleExpanded() => emit(state.copyWith(expanded: !state.expanded));

  Future<void> check() async {
    if (state.busy || state.target.trim().isEmpty) return;
    final currentRevision = state.revision;
    final input = state;
    emit(state.copyWith(busy: true, result: null, failed: false));
    try {
      final value = await service.check(
        input.configuration,
        input.target,
        customDraft: input.customDraft,
        port: input.customDraft == null ? 443 : int.parse(input.port),
        network: input.network,
      );
      if (isPageActive && state.revision == currentRevision) {
        emit(state.copyWith(result: value));
      }
    } catch (_) {
      if (isPageActive && state.revision == currentRevision) {
        emit(state.copyWith(failed: true));
      }
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  @override
  void disposePageResources() {
    target.removeListener(_targetChanged);
    port.removeListener(_portChanged);
    target.dispose();
    port.dispose();
  }
}

class RouteChecker extends StatefulWidget {
  final ConnectionConfiguration configuration;
  final RoutingProfileState? customDraft;
  const RouteChecker({
    super.key,
    required this.configuration,
    this.customDraft,
  });

  @override
  State<RouteChecker> createState() => _RouteCheckerState();
}

class _RouteCheckerState extends State<RouteChecker> {
  late final controller = RouteCheckerCubit(
    configuration: widget.configuration,
    customDraft: widget.customDraft,
  );

  @override
  void didUpdateWidget(RouteChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.updateConfiguration(widget.configuration, widget.customDraft);
  }

  @override
  void dispose() {
    unawaited(controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: controller,
    child: BlocBuilder<RouteCheckerCubit, RouteCheckerState>(
      builder: (context, state) {
        final l = AppLocalizations.of(context)!;
        final palette = ColorManager.palette(context);
        final current = state.result;
        final vpn =
            current != null &&
            !{'direct', 'block'}.contains(current.route.outboundTag);
        final reason = switch (current?.ruleName) {
          'private-ip' || 'private-domain' => l.prototypeDirectPrivateAddresses,
          'apple' => l.prototypeDirectAppleServices,
          'regions-domain' || 'regions-ip' => l.prototypeDirectRegions,
          'ads' => l.prototypeBlockAdDomains,
          final name? => name,
          null => l.prototypeNoneDefault,
        };
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                expanded: state.expanded,
                child: InkWell(
                  onTap: controller.toggleExpanded,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.globe,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.customDraft == null
                                    ? l.prototypeCheckWebsite
                                    : l.prototypeCheckRules,
                                style: AppTypography.routingSelectionTitle,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l.prototypeRuleCheckPrivacy,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.routingSelectionDescription
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        Icon(
                          state.expanded
                              ? LucideIcons.chevronDown
                              : LucideIcons.chevronRightDir,
                          size: 18,
                          color: palette.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: TextField(
                                controller: controller.target,
                                textDirection: TextDirection.ltr,
                                style: AppTypography.routingConditionInput,
                                decoration: InputDecoration(
                                  hintText: l.prototypeWebsiteOrIpAddress,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                onSubmitted: (_) => controller.check(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              textStyle: AppTypography.configurationTool,
                            ),
                            onPressed: state.busy || state.target.trim().isEmpty
                                ? null
                                : controller.check,
                            child: ButtonProgress(
                              busy: state.busy,
                              child: Text(l.prototypeCheck),
                            ),
                          ),
                        ],
                      ),
                      if (state.customDraft != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.prototypeTargetPort,
                                    style: AppTypography.routeIdentityLabel
                                        .copyWith(color: palette.mutedStrong),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 42,
                                    child: TextField(
                                      controller: controller.port,
                                      keyboardType: TextInputType.number,
                                      textDirection: TextDirection.ltr,
                                      style:
                                          AppTypography.routingConditionInput,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.prototypeNetworkType,
                                    style: AppTypography.routeIdentityLabel
                                        .copyWith(color: palette.mutedStrong),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 42,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: state.network,
                                      style: AppTypography.routingConditionInput
                                          .copyWith(color: palette.foreground),
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                      items: [
                                        for (final value in ['tcp', 'udp'])
                                          DropdownMenuItem(
                                            value: value,
                                            child: Text(value.toUpperCase()),
                                          ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          controller.updateNetwork(value);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          l.prototypeRuleCheckScope,
                          style: AppTypography.routingRowDescription.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                      if (state.failed)
                        Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(
                            l.prototypeCheckNetwork,
                            style: AppTypography.routingRowDescription.copyWith(
                              color: palette.destructive,
                            ),
                          ),
                        ),
                      if (current != null)
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            margin: const EdgeInsets.only(top: 9),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: palette.muted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DefaultTextStyle(
                              style: AppTypography.routingRowDescription
                                  .copyWith(color: palette.mutedForeground),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    vpn
                                        ? l.prototypeUseVpn
                                        : current.route.outboundTag == 'direct'
                                        ? l.prototypeDirect
                                        : l.prototypeBlock,
                                    style: AppTypography.routingSelectionTitle
                                        .copyWith(
                                          color: vpn
                                              ? palette.primary
                                              : current.route.outboundTag ==
                                                    'direct'
                                              ? palette.running
                                              : palette.destructive,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                  if (vpn)
                                    Text(
                                      current.path,
                                      textDirection: TextDirection.ltr,
                                    ),
                                  Text('${l.prototypeMatchedRule}: $reason'),
                                  const SizedBox(height: 5),
                                  Text(
                                    'DNS: ${current.dnsDirect == null
                                        ? '—'
                                        : current.dnsDirect!
                                        ? l.prototypeDirect
                                        : l.prototypeUseVpn}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
