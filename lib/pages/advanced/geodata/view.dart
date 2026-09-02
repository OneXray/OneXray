import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/view.dart' show formatTraffic;
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/geo_data/model.dart';

/// Default and custom datasets share file rows, never a second detail screen
/// embedded in the list. Only custom rows expose their dataset actions.
class GeoDataRows extends StatelessWidget {
  final List<PublishedGeoData> files;
  final bool custom;
  final bool busy;
  final void Function(PublishedGeoData) onOpen;
  final void Function(PublishedGeoData) onUpdate;
  final void Function(PublishedGeoData) onDelete;
  const GeoDataRows({
    super.key,
    required this.files,
    required this.custom,
    required this.busy,
    required this.onOpen,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = constraints.maxWidth >= 850;
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
          onPressed: busy ? null : () => onUpdate(file),
          child: Text(l.prototypeUpdate),
        ),
        IconButton(
          tooltip: l.prototypeDeleteCustomDataset,
          onPressed: busy ? null : () => onDelete(file),
          icon: const Icon(LucideIcons.trash2),
        ),
      ],
    );
  }
}
