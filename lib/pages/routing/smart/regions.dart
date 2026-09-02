import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/routing/geodata_suggestions.dart';
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DirectRegionsController extends ChangeNotifier {
  final Future<RegionCatalog> Function()? loadRegions;
  final Set<String> selected;
  List<String> codes = [];
  String query = '';
  bool busy = true;
  bool failed = false;
  bool _closed = false;

  DirectRegionsController(List<String> selectedCodes, {this.loadRegions})
    : selected = selectedCodes.toSet();

  Future<void> load() async {
    busy = true;
    failed = false;
    _notify();
    try {
      final regions =
          await (loadRegions?.call() ??
              RoutingGeodataIndex.load().then(
                (index) => index.regionCatalog(),
              ));
      if (_closed) return;
      codes = regions.regionCodes;
      selected.removeWhere((code) => !codes.contains(code));
    } catch (_) {
      failed = true;
    } finally {
      busy = false;
      _notify();
    }
  }

  List<String> visibleCodes(AppLocalizations l) {
    final value = query.trim().toLowerCase();
    return codes
        .where(
          (code) => '$code ${setupRegionLabel(l, code)}'.toLowerCase().contains(
            value,
          ),
        )
        .toList();
  }

  void search(String value) {
    query = value;
    _notify();
  }

  void toggle(String code) {
    if (!codes.contains(code)) return;
    if (!selected.remove(code)) selected.add(code);
    _notify();
  }

  void clear() {
    selected.clear();
    _notify();
  }

  void cancel(BuildContext context) => Navigator.of(context).pop();
  void save(BuildContext context) {
    if (!busy && !failed) Navigator.of(context).pop(selected.toList());
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

class DirectRegionsPage extends StatefulWidget {
  final List<String> selectedCodes;
  const DirectRegionsPage({super.key, required this.selectedCodes});
  @override
  State<DirectRegionsPage> createState() => _DirectRegionsPageState();
}

class _DirectRegionsPageState extends State<DirectRegionsPage> {
  late final controller = DirectRegionsController(widget.selectedCodes);
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final visible = controller.visibleCodes(l);
      return Scaffold(
        appBar: AppBar(title: Text(l.prototypeDirectRegions)),
        body: SafeArea(
          child: ResponsiveContent(
            desktopMaxWidth: 800,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.prototypeChooseDirectRegions),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: controller.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.search),
                          labelText: l.prototypeSearchDirectRegions,
                          hintText: l.prototypeRegionSearch,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.prototypeSelectedCount(
                                controller.selected.length,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: controller.selected.isEmpty
                                ? null
                                : controller.clear,
                            child: Text(l.prototypeClearAll),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: controller.busy
                      ? const Center(child: CircularProgressIndicator())
                      : controller.failed
                      ? Center(
                          child: TextButton(
                            onPressed: controller.load,
                            child: Text(l.prototypeRetry),
                          ),
                        )
                      : visible.isEmpty
                      ? Center(child: Text(l.prototypeNoRegionsFound))
                      : Semantics(
                          label: l.prototypeSupportedRegions,
                          child: ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final code = visible[index];
                              return CheckboxListTile(
                                value: controller.selected.contains(code),
                                onChanged: (_) => controller.toggle(code),
                                title: Text(setupRegionLabel(l, code)),
                                subtitle: Text(
                                  code,
                                  textDirection: TextDirection.ltr,
                                ),
                              );
                            },
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l.prototypeInstalledRegionsOnly,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: PageActionBar(
          children: [
            ShadButton.outline(
              onPressed: () => controller.cancel(context),
              child: Text(l.prototypeCancel),
            ),
            ShadButton(
              onPressed: controller.busy || controller.failed
                  ? null
                  : () => controller.save(context),
              child: Text(l.prototypeDone),
            ),
          ],
        ),
      );
    },
  );
}
