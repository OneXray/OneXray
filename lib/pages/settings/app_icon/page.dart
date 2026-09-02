import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/app_icon/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppIconPage extends StatelessWidget {
  const AppIconPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppIconController(),
      child: BlocBuilder<AppIconController, AppIconPageState>(
        builder: (context, state) {
          final controller = context.read<AppIconController>();
          final l10n = AppLocalizations.of(context)!;
          final useDockIconLabel = AppPlatform.isMacOS;
          return PopScope(
            canPop: !state.saving,
            child: Scaffold(
              appBar: AppBar(
                title: Text(l10n.prototypeAppIcon),
                leading: BackButton(
                  onPressed: () => controller.cancel(context),
                ),
              ),
              body: SafeArea(
                child: AbsorbPointer(
                  absorbing: state.loading || state.saving,
                  child: AppIconChoiceView(
                    selected: state.appIcon,
                    useDockIconAssets: useDockIconLabel,
                    description: useDockIconLabel
                        ? l10n.prototypeDockIconHint
                        : l10n.prototypeHomeScreenIconHint,
                    onSelected: controller.updateIcon,
                  ),
                ),
              ),
              bottomNavigationBar: PageActionBar(
                children: [
                  ShadButton.outline(
                    onPressed: state.saving
                        ? null
                        : () => controller.cancel(context),
                    child: Text(l10n.prototypeCancel),
                  ),
                  ShadButton(
                    onPressed: state.loading || state.saving
                        ? null
                        : () => controller.save(context),
                    child: Text(l10n.prototypeSave),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppIconChoiceView extends StatelessWidget {
  final AppIcon selected;
  final bool useDockIconAssets;
  final String description;
  final ValueChanged<AppIcon> onSelected;

  const AppIconChoiceView({
    super.key,
    required this.selected,
    required this.useDockIconAssets,
    required this.description,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      desktopMaxWidth: 760,
      child: Column(
        children: [
          SettingsPageIntro(
            title: useDockIconAssets
                ? l10n.prototypeDockPreview
                : l10n.prototypeHomeScreenPreview,
            description: description,
            trailing: _iconImage(_imageFor(selected), 76),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: AppIcon.values.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 3 ? 1.22 : 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final icon = AppIcon.values[index];
                    return _AppIconOption(
                      label: appIconLabel(l10n, icon),
                      image: _imageFor(icon),
                      selected: selected == icon,
                      onTap: () => onSelected(icon),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AssetGenImage _imageFor(AppIcon icon) {
    return useDockIconAssets ? icon.dockAssetImage : icon.assetImage;
  }

  static Widget _iconImage(AssetGenImage image, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: image.image(width: size, height: size, fit: BoxFit.cover),
    );
  }
}

String appIconLabel(AppLocalizations l10n, AppIcon icon) => switch (icon) {
  AppIcon.primary => l10n.prototypeIconBlue,
  AppIcon.black => l10n.prototypeIconBlack,
  AppIcon.green => l10n.prototypeIconGreen,
  AppIcon.orange => l10n.prototypeIconOrange,
  AppIcon.purple => l10n.prototypeIconPurple,
  AppIcon.red => l10n.prototypeIconRed,
};

class _AppIconOption extends StatelessWidget {
  final String label;
  final AssetGenImage image;
  final bool selected;
  final VoidCallback onTap;

  const _AppIconOption({
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: selected
                  ? ColorManager.selected(context)
                  : ColorManager.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? primary : ColorManager.border(context),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIconChoiceView._iconImage(image, 72),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: SettingsChoiceIndicator(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
