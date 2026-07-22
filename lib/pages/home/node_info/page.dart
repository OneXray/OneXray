import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/node_info/controller.dart';
import 'package:onexray/pages/home/node_info/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NodeInfoPage extends StatelessWidget {
  const NodeInfoPage({super.key, required this.params});

  final NodeInfoPageParams params;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NodeInfoController(params.selectedConfigId),
      child: BlocBuilder<NodeInfoController, NodeInfoPageState>(
        builder: (context, _) {
          final controller = context.read<NodeInfoController>();
          final viewState = controller.buildViewState(context);
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.nodeInfoPageTitle),
              actions: [
                ShadIconButton.ghost(
                  icon: viewState.refreshing
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.refreshCw),
                  onPressed: viewState.refreshing
                      ? null
                      : controller.retryConnectivityTest,
                ),
              ],
            ),
            body: SafeArea(child: NodeInfoContent(state: viewState)),
          );
        },
      ),
    );
  }
}

class NodeInfoContent extends StatelessWidget {
  const NodeInfoContent({super.key, required this.state});

  final NodeInfoViewState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        final horizontalPadding = viewport.maxWidth < 700 ? 16.0 : 24.0;
        return SingleChildScrollView(
          child: ResponsiveContent(
            desktopMaxWidth: 1040,
            adaptiveBreakpoint: 720,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                horizontalPadding,
                18,
                horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summary(context),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final sections = [
                        _sessionSection(context),
                        _locationSection(context),
                      ];
                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            sections[0],
                            const SizedBox(height: 18),
                            sections[1],
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: sections[0]),
                          const SizedBox(width: 18),
                          Expanded(child: sections[1]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summary(BuildContext context) {
    final statusColor = state.connected
        ? ColorManager.palette(context).runningText
        : ColorManager.secondaryText(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 2, 2, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ColorManager.border(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              state.direct ? LucideIcons.route : LucideIcons.shieldCheck,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.activePathName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.panelTitle.copyWith(
                          color: ColorManager.primaryText(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.supporting.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.protocol.isNotEmpty ||
                    state.connectionDetail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 5),
                    child: Text(
                      [
                        state.protocol,
                        state.connectionDetail,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.supporting.copyWith(
                        color: ColorManager.secondaryText(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionSection(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _InfoSection(
      title: localizations.nodeInfoPageCurrentSession,
      rows: [
        _InfoRowData(
          icon: LucideIcons.clock3,
          label: localizations.nodeInfoPageDuration,
          value: state.duration,
        ),
        _InfoRowData(
          icon: LucideIcons.activity,
          label: localizations.nodeInfoPageDelay,
          value: state.delay,
        ),
        _InfoRowData(
          icon: LucideIcons.network,
          label: localizations.nodeInfoPageTraffic,
          value: state.traffic,
        ),
      ],
    );
  }

  Widget _locationSection(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _InfoSection(
      title: localizations.nodeInfoPageNetworkLocation,
      rows: [
        _InfoRowData(
          icon: LucideIcons.globe2,
          label: localizations.nodeInfoPageIP,
          value: state.ipAddress,
        ),
        _InfoRowData(
          icon: LucideIcons.network,
          label: localizations.nodeInfoPageIPVersion,
          value: state.ipVersion,
        ),
        _InfoRowData(
          icon: LucideIcons.mapPin,
          label: localizations.nodeInfoPageCountryOrRegion,
          value: state.country,
        ),
        _InfoRowData(
          icon: LucideIcons.map,
          label: localizations.nodeInfoPageRegion,
          value: state.region,
        ),
        _InfoRowData(
          icon: LucideIcons.building2,
          label: localizations.nodeInfoPageCity,
          value: state.city,
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7),
          child: Text(
            title,
            style: AppTypography.navigationLabel.copyWith(
              color: ColorManager.secondaryText(context),
            ),
          ),
        ),
        ShadCard(
          padding: EdgeInsets.zero,
          radius: BorderRadius.circular(8),
          width: double.infinity,
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                _InfoRow(data: rows[index]),
                if (index < rows.length - 1)
                  Divider(height: 1, color: ColorManager.border(context)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    data.icon,
                    size: 17,
                    color: ColorManager.secondaryText(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.label,
                      textAlign: TextAlign.start,
                      style: AppTypography.supporting.copyWith(
                        color: ColorManager.secondaryText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SelectableText(
                  data.value,
                  textAlign: TextAlign.end,
                  style: AppTypography.navigationLabel.copyWith(
                    color: ColorManager.primaryText(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
