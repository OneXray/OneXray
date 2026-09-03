import 'package:flutter/material.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GeoDataFilePage extends StatefulWidget {
  const GeoDataFilePage({super.key, required this.fileId});
  final int fileId;
  @override
  State<GeoDataFilePage> createState() => _GeoDataFilePageState();
}

class _GeoDataFilePageState extends State<GeoDataFilePage> {
  late final controller = GeoDataFileController(widget.fileId);
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    scroll.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final palette = ColorManager.palette(context);
      final file = controller.file;
      final codes = controller.codes;
      return Scaffold(
        appBar: AppBar(title: Text(file?.fileName ?? l.prototypeRoutingData)),
        body: SafeArea(
          child: ResponsiveContent(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : file == null || controller.failed
                ? Center(child: Text(l.prototypeRoutingFileUnavailable))
                : Scrollbar(
                    controller: scroll,
                    child: CustomScrollView(
                      controller: scroll,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceHover,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: Text(
                                      l.prototypeReadOnly,
                                      style: AppTypography.geodataReadonly
                                          .copyWith(color: palette.mutedStrong),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SettingSection(
                                  title: l.prototypeDataSource,
                                  icon: LucideIcons.globe2,
                                  padding: EdgeInsets.zero,
                                  dividerIndent: 0,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        spacing: 12,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  l.prototypeSourceUrl,
                                                  style: AppTypography
                                                      .geodataSourceLabel
                                                      .copyWith(
                                                        color: palette
                                                            .mutedForeground,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                SelectableText(
                                                  file.row.url,
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  style: AppTypography
                                                      .geodataSourceUrl,
                                                ),
                                              ],
                                            ),
                                          ),
                                          _copyButton(
                                            context,
                                            tooltip: l.prototypeCopySourceUrl,
                                            onPressed: () => controller.copy(
                                              context,
                                              file.row.url,
                                              l.prototypeSourceUrlCopied,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SettingRow(
                                      title: l.prototypeDataType,
                                      titleStyle: AppTypography.geodataBody,
                                      minHeight: 43,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 13,
                                          ),
                                      trailing: Text(
                                        file.row.type == 'ip'
                                            ? 'GeoIP'
                                            : 'GeoSite',
                                        style: AppTypography.settingsRow,
                                      ),
                                    ),
                                    SettingRow(
                                      title: l.prototypeCategories,
                                      titleStyle: AppTypography.geodataBody,
                                      minHeight: 43,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 13,
                                          ),
                                      trailing: Text(
                                        '${file.index.categoryCount}',
                                        style: AppTypography.settingsRow,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Semantics(
                                  label: l.prototypeSearchCategories,
                                  child: ShadInput(
                                    controller: controller.search,
                                    onChanged: controller.searchChanged,
                                    constraints: const BoxConstraints(
                                      minHeight: 43,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    gap: 10,
                                    style: AppTypography.geodataBody,
                                    placeholderStyle: AppTypography.geodataBody
                                        .copyWith(
                                          color: palette.mutedForeground,
                                        ),
                                    placeholder: Text(
                                      l.prototypeSearchCategories,
                                    ),
                                    leading: Icon(
                                      LucideIcons.search,
                                      size: 18,
                                      color: palette.mutedForeground,
                                    ),
                                    decoration: ShadDecoration(
                                      border: ShadBorder.all(
                                        color: palette.border,
                                        radius: BorderRadius.circular(
                                          AppRadii.card,
                                        ),
                                      ),
                                    ),
                                    trailing: controller.search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: l.prototypeClear,
                                            onPressed: controller.clearSearch,
                                            style: IconButton.styleFrom(
                                              minimumSize: const Size.square(
                                                18,
                                              ),
                                              maximumSize: const Size.square(
                                                18,
                                              ),
                                              padding: EdgeInsets.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            icon: const Icon(
                                              LucideIcons.x,
                                              size: 17,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                          sliver: DecoratedSliver(
                            decoration: BoxDecoration(
                              border: Border.all(color: palette.border),
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                            ),
                            sliver: SliverPadding(
                              padding: const EdgeInsets.all(1),
                              sliver: codes.isEmpty
                                  ? SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Text(
                                          l.prototypeNoMatchingCategories,
                                          style: AppTypography.geodataEmpty
                                              .copyWith(
                                                color: palette.mutedForeground,
                                              ),
                                        ),
                                      ),
                                    )
                                  : GeoDataCategorySliver(
                                      file: file,
                                      codes: codes,
                                      onCopy: (reference) => controller.copy(
                                        context,
                                        reference,
                                        l.prototypeRuleReferenceCopied,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}

class GeoDataCategorySliver extends StatelessWidget {
  const GeoDataCategorySliver({
    super.key,
    required this.file,
    required this.codes,
    required this.onCopy,
  });

  final PublishedGeoData file;
  final List<XrayGeoListCodes> codes;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) => SliverPrototypeExtentList.builder(
    prototypeItem: _row(context, 0),
    itemCount: codes.length,
    itemBuilder: _row,
  );

  Widget _row(BuildContext context, int index) {
    final l = AppLocalizations.of(context)!;
    final code = codes[index];
    final reference = file.reference(code.code!);
    final palette = ColorManager.palette(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: index == codes.length - 1
            ? null
            : Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  code.code!,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.geodataCategory,
                ),
                const SizedBox(height: 5),
                Text(
                  reference,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.geodataReference.copyWith(
                    color: palette.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            l.prototypeRuleCount(code.ruleCount!),
            style: AppTypography.geodataValue.copyWith(
              color: palette.mutedForeground,
            ),
            maxLines: 1,
          ),
          _copyButton(
            context,
            tooltip: '${l.prototypeCopyRuleReference}: $reference',
            onPressed: () => onCopy(reference),
          ),
        ],
      ),
    );
  }
}

Widget _copyButton(
  BuildContext context, {
  required String tooltip,
  required VoidCallback onPressed,
}) => IconButton(
  tooltip: tooltip,
  onPressed: onPressed,
  style: IconButton.styleFrom(
    minimumSize: const Size.square(36),
    maximumSize: const Size.square(36),
    padding: EdgeInsets.zero,
    foregroundColor: ColorManager.palette(context).mutedStrong,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  icon: const Icon(LucideIcons.copy, size: 17),
);
