import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/view.dart' show formatTraffic;
import 'package:onexray/pages/theme/font.dart';
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
    final l = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = constraints.maxWidth >= 850;
        if (!table) return _mobileList(context);
        final headers = [
          l.prototypeFileName,
          l.prototypeSource,
          l.prototypeSize,
          l.prototypeLastSuccessfulUpdate,
        ];
        return Column(
          children: [
            if (table)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < headers.length; index++)
                      Expanded(
                        flex: index == 2 ? 1 : 2,
                        child: Text(headers[index], style: AppTypography.badge),
                      ),
                    if (custom) const SizedBox(width: 144),
                  ],
                ),
              ),
            for (final file in files)
              Semantics(
                container: true,
                label: file.builtIn
                    ? l.prototypeDefaultRoutingData
                    : l.prototypeCustomRuleDataset(file.row.id),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: table
                      ? Row(
                          children: [
                            Expanded(flex: 2, child: _name(context, file)),
                            Expanded(
                              flex: 2,
                              child: Text(
                                file.sourceHost,
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                formatTraffic(file.bytes),
                                style: AppTypography.numeric,
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                material.formatMediumDate(
                                  file.row.timestamp.toLocal(),
                                ),
                              ),
                            ),
                            if (custom)
                              SizedBox(
                                width: 144,
                                child: _actions(context, file),
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _name(context, file),
                            const SizedBox(height: 8),
                            Text(
                              file.sourceHost,
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  formatTraffic(file.bytes),
                                  style: AppTypography.numeric,
                                  textDirection: TextDirection.ltr,
                                ),
                                Text(
                                  '${l.prototypeLastSuccessfulUpdate}: ${material.formatMediumDate(file.row.timestamp.toLocal())}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            if (custom)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: _actions(context, file),
                              ),
                          ],
                        ),
                ),
              ),
          ],
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
    style: TextButton.styleFrom(alignment: AlignmentDirectional.centerStart),
    onPressed: () => onOpen(file),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(file.fileName, textDirection: TextDirection.ltr)),
        const SizedBox(width: 4),
        const Icon(LucideIcons.chevronRightDir, size: 16),
      ],
    ),
  );

  Widget _actions(BuildContext context, PublishedGeoData file) {
    final l = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: _busy(file) ? null : () => onUpdate(file),
          child: ButtonProgress(
            busy: updating.contains(file.row.id),
            child: Text(l.prototypeUpdate),
          ),
        ),
        IconButton(
          tooltip: l.prototypeDeleteCustomDataset,
          onPressed: _busy(file) ? null : () => onDelete(file),
          icon: deleting.contains(file.row.id)
              ? const ButtonProgressIndicator()
              : const Icon(LucideIcons.trash2),
        ),
      ],
    );
  }
}
