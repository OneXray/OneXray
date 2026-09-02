import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/controller.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

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
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Chip(label: Text(l.prototypeReadOnly)),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  l.prototypeDataSource,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l.prototypeSourceUrl,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          const SizedBox(height: 4),
                                          SelectableText(
                                            file.row.url,
                                            textDirection: TextDirection.ltr,
                                            style: AppTypography.code,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: l.prototypeCopySourceUrl,
                                      onPressed: () => controller.copy(
                                        context,
                                        file.row.url,
                                        l.prototypeSourceUrlCopied,
                                      ),
                                      icon: const Icon(LucideIcons.copy),
                                    ),
                                  ],
                                ),
                                const Divider(height: 28),
                                Row(
                                  children: [
                                    Expanded(child: Text(l.prototypeDataType)),
                                    Text(
                                      file.row.type == 'ip'
                                          ? 'GeoIP'
                                          : 'GeoSite',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(l.prototypeCategories),
                                    ),
                                    Text(
                                      '${file.index.categoryCount}',
                                      style: AppTypography.numeric,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: controller.search,
                                  onChanged: controller.searchChanged,
                                  decoration: InputDecoration(
                                    labelText: l.prototypeSearchCategories,
                                    prefixIcon: const Icon(LucideIcons.search),
                                    suffixIcon: controller.search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: l.prototypeClear,
                                            onPressed: controller.clearSearch,
                                            icon: const Icon(LucideIcons.x),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (codes.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(l.prototypeNoMatchingCategories),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            sliver: SliverList.builder(
                              itemCount: codes.length,
                              itemBuilder: (context, index) {
                                final code = codes[index];
                                return Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        code.code!,
                                        textDirection: TextDirection.ltr,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.reference(code.code!),
                                            textDirection: TextDirection.ltr,
                                            style: AppTypography.code,
                                          ),
                                          Text(
                                            l.prototypeRuleCount(
                                              code.ruleCount!,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        tooltip:
                                            '${l.prototypeCopyRuleReference}: ${file.reference(code.code!)}',
                                        onPressed: () => controller.copy(
                                          context,
                                          file.reference(code.code!),
                                          l.prototypeRuleReferenceCopied,
                                        ),
                                        icon: const Icon(LucideIcons.copy),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                );
                              },
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
