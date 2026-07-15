import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/tun/installed_app/controller.dart';
import 'package:onexray/pages/core/tun/installed_app/params.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InstalledAppPage extends StatelessWidget {
  final InstalledAppParams params;

  const InstalledAppPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InstalledAppController(params),
      child: BlocBuilder<InstalledAppController, InstalledAppPageState>(
        builder: (context, state) {
          final controller = context.read<InstalledAppController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.installedAppPageTitle,
            onSave: () => controller.save(context),
            body: ResponsiveContent(
              desktopMaxWidth: 760,
              child: LayoutBuilder(
                builder: (context, constraints) => Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    16,
                    constraints.maxWidth < 560 ? 12 : 16,
                    16,
                    16,
                  ),
                  child: Column(
                    children: [
                      _toolbar(context, controller, state),
                      const SizedBox(height: 10),
                      Expanded(child: _appCard(context, controller, state)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolbar(
    BuildContext context,
    InstalledAppController controller,
    InstalledAppPageState state,
  ) {
    return Row(
      children: [
        Expanded(
          child: ListSearchField(
            controller: controller.searchController,
            onChanged: controller.keywordChanged,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 12),
        SettingsBadge(label: "${state.selections.length}"),
      ],
    );
  }

  Widget _appCard(
    BuildContext context,
    InstalledAppController controller,
    InstalledAppPageState state,
  ) {
    return ShadCard(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: state.apps.isEmpty
          ? ListEmptyView(
              message: AppLocalizations.of(context)!.installedAppPageNoApp,
            )
          : ListView.separated(
              itemCount: state.apps.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final app = state.apps[index];
                final selected = state.selections.contains(app.packageName);
                return DataListRow(
                  title: app.name,
                  subtitle: app.packageName,
                  onTap: () =>
                      controller.updateSelections(!selected, app.packageName),
                  trailing: Checkbox(
                    value: selected,
                    onChanged: (value) =>
                        controller.updateSelections(value, app.packageName),
                  ),
                );
              },
            ),
    );
  }
}
