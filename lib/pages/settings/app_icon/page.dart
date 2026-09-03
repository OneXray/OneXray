import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/app_icon/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
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
                    enabled: !state.saving,
                    onPressed: state.saving
                        ? null
                        : () => controller.cancel(context),
                    child: Text(l10n.prototypeCancel),
                  ),
                  ShadButton(
                    enabled: !state.loading && !state.saving,
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
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return SettingsPageScroll(
      desktopMaxWidth: 760,
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            description,
            style: AppTypography.settingsDetailNote.copyWith(
              color: ColorManager.secondaryText(context),
            ),
          ),
          const SizedBox(height: 23),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              children: [
                _iconImage(_imageFor(selected), 100),
                const SizedBox(height: 9),
                Text('OneXray', style: AppTypography.iconPreviewBrand),
                const SizedBox(height: 9),
                Text(
                  useDockIconAssets
                      ? l10n.prototypeDockPreview
                      : l10n.prototypeHomeScreenPreview,
                  style: AppTypography.iconPreviewCaption.copyWith(
                    color: ColorManager.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 23),
          ShadRadioGroup<AppIcon>(
            axis: Axis.horizontal,
            initialValue: selected,
            onChanged: (icon) {
              if (icon != null && icon != selected) onSelected(icon);
            },
            items: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = mobile ? 10.0 : 14.0;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final icon in AppIcon.values)
                        SizedBox(
                          width: (constraints.maxWidth - gap * 2) / 3,
                          child: _AppIconOption(
                            icon: icon,
                            label: appIconLabel(l10n, icon),
                            image: _imageFor(icon),
                            selected: selected == icon,
                            onTap: () => onSelected(icon),
                            mobile: mobile,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  AssetGenImage _imageFor(AppIcon icon) {
    return useDockIconAssets ? icon.dockAssetImage : icon.assetImage;
  }

  static Widget _iconImage(AssetGenImage image, double size) {
    return image.image(width: size, height: size, fit: BoxFit.contain);
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
  final AppIcon icon;
  final String label;
  final AssetGenImage image;
  final bool selected;
  final VoidCallback onTap;
  final bool mobile;

  const _AppIconOption({
    required this.icon,
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
    required this.mobile,
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
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 5 : 10,
              vertical: mobile ? 14 : 18,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? ColorManager.selected(context)
                  : ColorManager.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? primary : ColorManager.border(context),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconChoiceView._iconImage(image, mobile ? 62 : 72),
                const SizedBox(height: 12),
                ShadRadio<AppIcon>(
                  value: icon,
                  decoration: selected
                      ? ShadDecoration(
                          border: ShadBorder.all(color: primary, width: 1),
                        )
                      : null,
                  radioPadding: EdgeInsets.zero,
                  padding: const EdgeInsetsDirectional.only(start: 7),
                  label: Text(label, style: AppTypography.iconChoice),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
