import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/app_icon/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/settings_page.dart';

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
          return SettingsPageScaffold(
            title: l10n.appIconPageTitle,
            onSave: () => controller.save(context),
            saveLabel: l10n.buttonSave,
            body: AppIconChoiceView(
              selected: state.appIcon,
              onSelected: controller.updateIcon,
            ),
          );
        },
      ),
    );
  }
}

class AppIconChoiceView extends StatelessWidget {
  final AppIcon selected;
  final ValueChanged<AppIcon> onSelected;

  const AppIconChoiceView({
    super.key,
    required this.selected,
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
            title: l10n.appIconPageSelect,
            description: l10n.appIconPageDescription,
            trailing: _iconImage(selected.assetImage, 76),
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
                      label: _label(l10n, icon),
                      image: icon.assetImage,
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

  String _label(AppLocalizations l10n, AppIcon icon) {
    return switch (icon) {
      AppIcon.primary => l10n.appIconPageBlue,
      AppIcon.black => l10n.appIconPageBlack,
      AppIcon.green => l10n.appIconPageGreen,
      AppIcon.orange => l10n.appIconPageOrange,
      AppIcon.purple => l10n.appIconPagePurple,
      AppIcon.red => l10n.appIconPageRed,
    };
  }

  static Widget _iconImage(AssetGenImage image, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: image.image(width: size, height: size, fit: BoxFit.cover),
    );
  }
}

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
    return Material(
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
    );
  }
}
