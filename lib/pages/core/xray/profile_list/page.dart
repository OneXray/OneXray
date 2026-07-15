import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile_list/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayProfileListPage extends StatelessWidget {
  const XrayProfileListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayProfileListController(),
      child: BlocBuilder<XrayProfileListController, XrayProfileListPageState>(
        builder: (context, state) {
          final controller = context.read<XrayProfileListController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.xrayProfileListPageTitle,
            onSave: () => controller.save(context),
            actions: [
              IconButton(
                tooltip: state.searching
                    ? AppLocalizations.of(context)!.buttonCancel
                    : AppLocalizations.of(context)!.listSearchHint,
                onPressed: controller.toggleSearch,
                icon: Icon(
                  state.searching ? LucideIcons.x : LucideIcons.search,
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.buttonAdd,
                onPressed: () => controller.addXrayProfile(context),
                icon: const Icon(LucideIcons.plus),
              ),
            ],
            body: _body(context, controller, state),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    XrayProfileListController controller,
    XrayProfileListPageState state,
  ) {
    return SettingsPageScroll(
      child: Column(
        children: [
          if (state.searching)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 0),
              child: ListSearchField(
                controller: controller.searchController,
                hintText: AppLocalizations.of(context)!.listSearchHint,
                onChanged: controller.updateSearchQuery,
              ),
            ),
          if (state.profiles.isEmpty)
            SizedBox(
              height: 320,
              child: ListEmptyView(
                message: state.query.isEmpty
                    ? AppLocalizations.of(context)!.xrayProfileListPageEmpty
                    : AppLocalizations.of(context)!.listNoSearchResult,
                icon: state.query.isEmpty
                    ? LucideIcons.listFilter
                    : LucideIcons.searchX,
                actionLabel: state.query.isEmpty
                    ? AppLocalizations.of(context)!.buttonAdd
                    : null,
                actionIcon: LucideIcons.plus,
                onAction: state.query.isEmpty
                    ? () => controller.addXrayProfile(context)
                    : null,
              ),
            )
          else
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 4),
              child: Column(
                children: state.profiles
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 8),
                        child: _profileCard(
                          context,
                          controller,
                          state,
                          item.config,
                          builtIn: item.builtIn,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    XrayProfileListController controller,
    XrayProfileListPageState state,
    CoreConfigData config, {
    required bool builtIn,
  }) {
    final selected = config.id == state.xrayProfileId;
    return ShadCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      backgroundColor: selected
          ? Color.alphaBlend(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              ColorManager.surface(context),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => controller.updateXrayProfileId(context, config.id),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(15, 13, 10, 13),
                child: Row(
                  children: [
                    _selectionIndicator(context, selected),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  config.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.rowTitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 7),
                                SettingsBadge(
                                  label: AppLocalizations.of(
                                    context,
                                  )!.listStatusSelected,
                                  selected: true,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            builtIn
                                ? AppLocalizations.of(
                                    context,
                                  )!.xrayProfileSimplePageTitle
                                : AppLocalizations.of(
                                    context,
                                  )!.xrayProfileUIPageTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.supporting.copyWith(
                              color: ColorManager.secondaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: IconMenuId.edit.title,
            onPressed: () =>
                controller.moreAction(context, config, IconMenuId.edit),
            icon: const Icon(LucideIcons.pencil, size: 18),
          ),
          if (!builtIn)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: AppMenuButton<IconMenuId>(
                icon: LucideIcons.ellipsis,
                entries: iconMenuEntries([
                  IconMenuId.share,
                  IconMenuId.copy,
                  if (!selected) IconMenuId.delete,
                ]),
                onSelected: (menuId) =>
                    controller.moreAction(context, config, menuId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionIndicator(BuildContext context, bool selected) {
    return Container(
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 1.5,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : ColorManager.secondaryText(context),
        ),
      ),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : null,
    );
  }
}
