import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/view.dart' show formatTraffic;
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/pages/widget/button_progress.dart';

/// Default and custom datasets share file rows, never a second detail screen
/// embedded in the list. Only custom rows expose their dataset actions.
class GeoDataRows extends StatelessWidget {
  final List<PublishedGeoData> files;
  final bool custom;
  final bool busy;
  final Set<int> updating;
  final Set<int> deleting;
  final void Function(PublishedGeoData) onOpen;
  final void Function(PublishedGeoData) onUpdate;
  final void Function(PublishedGeoData) onDelete;
  const GeoDataRows({
    super.key,
    required this.files,
    required this.custom,
    required this.busy,
    this.updating = const {},
    this.deleting = const {},
    required this.onOpen,
    required this.onUpdate,
    required this.onDelete,
  });

  bool _busy(PublishedGeoData file) =>
      busy || updating.contains(file.row.id) || deleting.contains(file.row.id);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      return _mobileList(context);
    }
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final headers = [
      l.prototypeFileName,
      l.prototypeSource,
      l.prototypeSize,
      l.prototypeLastSuccessfulUpdate,
      if (custom) l.prototypeAction,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth =
            constraints.maxWidth - 24 - (headers.length - 1) * 14;
        final actionsWidth = custom
            ? math.max(84.0, usableWidth * .8 / 5)
            : 0.0;
        final dataWidth = usableWidth - actionsWidth;
        final widths = [
          for (final ratio in const [1.05, 1.3, .7, 1.15])
            dataWidth * ratio / 4.2,
          if (custom) actionsWidth,
        ];
        Widget line(List<Widget> cells, {bool header = false}) => Container(
          constraints: BoxConstraints(minHeight: header ? 42 : 56),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          child: Row(
            children: [
              for (var index = 0; index < cells.length; index++) ...[
                if (index > 0) const SizedBox(width: 14),
                SizedBox(width: widths[index], child: cells[index]),
              ],
            ],
          ),
        );
        Widget value(String text, {bool ltr = false}) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: ltr ? TextDirection.ltr : null,
          style: AppTypography.geodataTableBody,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: Column(
            children: [
              line([
                for (final title in headers)
                  Text(
                    title,
                    style: AppTypography.geodataTableHeading.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
              ], header: true),
              for (final file in files)
                Semantics(
                  container: true,
                  label: file.builtIn
                      ? l.prototypeDefaultRoutingData
                      : l.prototypeCustomRuleDataset(file.row.id),
                  child: line([
                    _name(context, file),
                    value(file.sourceHost, ltr: true),
                    value(formatTraffic(file.bytes), ltr: true),
                    value(
                      DateFormat.yMd(Localizations.localeOf(context).toString())
                          .add_Hm()
                          .format(file.row.timestamp.toLocal()),
                    ),
                    if (custom) _actions(context, file),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileList(BuildContext context) {
    final palette = ColorManager.palette(context);
    Widget group(List<PublishedGeoData> rows) => Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) Divider(height: 0, color: palette.border),
            _mobileRow(context, rows[index]),
          ],
        ],
      ),
    );
    if (!custom) return group(files);
    return Column(
      spacing: 8,
      children: [
        for (final file in files) group([file]),
      ],
    );
  }

  Widget _mobileRow(BuildContext context, PublishedGeoData file) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final date = file.row.timestamp.toLocal();
    Widget field(String label, String value, {bool ltr = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        Text(
          label,
          style: AppTypography.geodataMeta.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        Text(
          value,
          style: AppTypography.geodataValue,
          textDirection: ltr ? TextDirection.ltr : null,
        ),
      ],
    );
    return Semantics(
      container: true,
      label: file.builtIn
          ? l.prototypeDefaultRoutingData
          : l.prototypeCustomRuleDataset(file.row.id),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 9,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: custom
                        ? updating.contains(file.row.id)
                              ? 106
                              : 82
                        : 0,
                  ),
                  child: InkWell(
                    onTap: () => onOpen(file),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Text(
                            l.prototypeFileName,
                            style: AppTypography.geodataMeta.copyWith(
                              color: palette.mutedForeground,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  file.fileName,
                                  textDirection: TextDirection.ltr,
                                  style: AppTypography.geodataValue.copyWith(
                                    color: palette.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                LucideIcons.chevronRightDir,
                                size: 15,
                                color: palette.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                field(l.prototypeSource, file.sourceHost, ltr: true),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: field(
                        l.prototypeSize,
                        formatTraffic(file.bytes),
                        ltr: true,
                      ),
                    ),
                    Expanded(
                      child: field(
                        l.prototypeLastSuccessfulUpdate,
                        DateFormat.yMd(
                          Localizations.localeOf(context).toString(),
                        ).add_Hm().format(date),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (custom)
            PositionedDirectional(
              top: 7,
              end: 8,
              child: Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: AppTypography.geodataAction,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.standard,
                    ),
                    onPressed: _busy(file) ? null : () => onUpdate(file),
                    child: ButtonProgress(
                      busy: updating.contains(file.row.id),
                      child: Text(l.prototypeUpdate),
                    ),
                  ),
                  IconButton(
                    tooltip: l.prototypeDeleteCustomDataset,
                    style: IconButton.styleFrom(
                      foregroundColor: palette.destructive,
                      minimumSize: const Size.square(30),
                      maximumSize: const Size.square(30),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _busy(file) ? null : () => onDelete(file),
                    icon: deleting.contains(file.row.id)
                        ? const ButtonProgressIndicator()
                        : const Icon(LucideIcons.trash2, size: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _name(BuildContext context, PublishedGeoData file) => TextButton(
    style: TextButton.styleFrom(
      alignment: AlignmentDirectional.centerStart,
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(vertical: 8),
      textStyle: AppTypography.geodataTableBody,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: () => onOpen(file),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(file.fileName, textDirection: TextDirection.ltr)),
        const SizedBox(width: 6),
        const Icon(LucideIcons.chevronRightDir, size: 15),
      ],
    ),
  );

  Widget _actions(BuildContext context, PublishedGeoData file) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Flexible(
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: AppTypography.geodataDesktopAction,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _busy(file) ? null : () => onUpdate(file),
            child: ButtonProgress(
              busy: updating.contains(file.row.id),
              child: Text(
                l.prototypeUpdate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l.prototypeDeleteCustomDataset,
          style: IconButton.styleFrom(
            foregroundColor: palette.destructive,
            fixedSize: const Size.square(30),
            minimumSize: const Size.square(30),
            maximumSize: const Size.square(30),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _busy(file) ? null : () => onDelete(file),
          icon: deleting.contains(file.row.id)
              ? const ButtonProgressIndicator()
              : const Icon(LucideIcons.trash2, size: 16),
        ),
      ],
    );
  }
}
