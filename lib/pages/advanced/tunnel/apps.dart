import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/tun/app_icon/controller.dart';
import 'package:onexray/pages/core/tun/app_icon/view.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class AndroidAppsController extends ChangeNotifier {
  final Set<String> selected;
  final Future<List<AndroidAppInfo>> Function() loadApps;
  List<AndroidAppInfo> apps = [];
  bool loading = true;
  bool failed = false;
  String query = '';
  bool _closed = false;
  AndroidAppsController(
    List<String> selected, {
    Future<List<AndroidAppInfo>> Function()? loadApps,
  }) : selected = selected.toSet(),
       loadApps = loadApps ?? AppHostApi().getInstalledApps;

  Future<void> load() async {
    loading = true;
    failed = false;
    notify();
    try {
      final result = await loadApps();
      if (!_closed) {
        apps = result;
      }
    } catch (_) {
      failed = true;
    } finally {
      loading = false;
      notify();
    }
  }

  List<AndroidAppInfo> get visible => apps
      .where(
        (app) =>
            app.name.toLowerCase().contains(query.toLowerCase()) ||
            app.packageName.toLowerCase().contains(query.toLowerCase()),
      )
      .toList();

  // Keep stored, no-longer-installed IDs visible so the user can remove them.
  List<String> get missing => selected
      .where(
        (id) =>
            !apps.any((app) => app.packageName == id) &&
            id.toLowerCase().contains(query.toLowerCase()),
      )
      .toList();

  void search(String value) {
    query = value;
    notify();
  }

  void toggle(String id) {
    if (!selected.remove(id)) {
      selected.add(id);
    }
    notify();
  }

  void finish(BuildContext context) =>
      Navigator.of(context).pop(selected.toList());
  void cancel(BuildContext context) => Navigator.of(context).pop();
  void notify() {
    if (!_closed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

class AndroidAppsPage extends StatefulWidget {
  final String mode;
  final List<String> selected;
  const AndroidAppsPage({
    super.key,
    required this.mode,
    required this.selected,
  });
  @override
  State<AndroidAppsPage> createState() => _AndroidAppsPageState();
}

class _AndroidAppsPageState extends State<AndroidAppsPage> {
  late final controller = AndroidAppsController(widget.selected)..load();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TunAppIconController(),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final l = AppLocalizations.of(context)!;
        final rows = controller.visible;
        final missing = controller.missing;
        return Scaffold(
          appBar: AppBar(title: Text(l.prototypeSelectApps)),
          body: SafeArea(
            child: ResponsiveContent(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.mode == 'included'
                              ? l.prototypeChooseAppsUseVpn
                              : l.prototypeChooseAppsBypassVpn,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: l.prototypeSearchInstalledApps,
                            prefixIcon: const Icon(LucideIcons.search),
                          ),
                          onChanged: controller.search,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.prototypeAppsSelectedCount(
                            controller.selected.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: controller.loading
                        ? const Center(child: CircularProgressIndicator())
                        : controller.failed
                        ? Center(
                            child: TextButton(
                              onPressed: controller.load,
                              child: Text(l.prototypeRetry),
                            ),
                          )
                        : rows.isEmpty && missing.isEmpty
                        ? Center(child: Text(l.prototypeNoMatchingApps))
                        : ListView.builder(
                            itemCount: rows.length + missing.length,
                            itemBuilder: (context, index) {
                              if (index >= rows.length) {
                                final id = missing[index - rows.length];
                                return SettingRow(
                                  title: id,
                                  subtitle: l.prototypeTemporarilyUnavailable,
                                  leading: const Icon(LucideIcons.package),
                                  trailing: Checkbox(
                                    value: true,
                                    onChanged: (_) => controller.toggle(id),
                                  ),
                                  onTap: () => controller.toggle(id),
                                );
                              }
                              final app = rows[index];
                              return SettingRow(
                                title: app.name,
                                subtitle: app.packageName,
                                leading: SizedBox.square(
                                  dimension: 36,
                                  child: AppIconView(
                                    packageName: app.packageName,
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: controller.selected.contains(
                                    app.packageName,
                                  ),
                                  onChanged: (_) =>
                                      controller.toggle(app.packageName),
                                ),
                                onTap: () => controller.toggle(app.packageName),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              OutlinedButton(
                onPressed: () => controller.cancel(context),
                child: Text(l.prototypeCancel),
              ),
              FilledButton(
                onPressed: controller.loading || controller.failed
                    ? null
                    : () => controller.finish(context),
                child: Text(l.prototypeDone),
              ),
            ],
          ),
        );
      },
    ),
  );
}
