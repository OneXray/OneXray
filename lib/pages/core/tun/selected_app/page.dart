import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/tun/selected_app/controller.dart';
import 'package:onexray/pages/core/tun/selected_app/params.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SelectedAppPage extends StatelessWidget {
  final SelectedAppParams params;

  const SelectedAppPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SelectedAppController(params),
      child: BlocBuilder<SelectedAppController, SelectedAppPageState>(
        builder: (context, state) {
          final controller = context.read<SelectedAppController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.selectedAppPageTitle,
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
    SelectedAppController controller,
    SelectedAppPageState state,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "${state.apps.length} ${AppLocalizations.of(context)!.selectedAppPageTitle}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.navigationLabel,
          ),
        ),
        const SizedBox(width: 12),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          leading: const Icon(LucideIcons.plus, size: 16),
          onPressed: () => controller.gotoInstalledApp(context),
          child: Text(AppLocalizations.of(context)!.buttonAdd),
        ),
      ],
    );
  }

  Widget _appCard(
    BuildContext context,
    SelectedAppController controller,
    SelectedAppPageState state,
  ) {
    return ShadCard(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: state.apps.isEmpty
          ? ListEmptyView(
              message: AppLocalizations.of(context)!.selectedAppPageNoApp,
            )
          : ListView.separated(
              itemCount: state.apps.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final app = state.apps[index];
                return DataListRow(
                  title: app.name,
                  subtitle: app.packageName,
                  trailing: IconButton(
                    tooltip: AppLocalizations.of(context)!.menuDelete,
                    onPressed: () => controller.removeApp(app),
                    icon: const Icon(LucideIcons.trash2, size: 18),
                  ),
                );
              },
            ),
    );
  }
}
