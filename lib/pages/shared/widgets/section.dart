import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SectionView extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool descriptionBelow;
  final double? headerInset;

  const SectionView({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.action,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 11),
    this.descriptionBelow = false,
    this.headerInset,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.isNotEmpty;
    final hasDescription = description != null && description!.isNotEmpty;
    final hasHeader =
        hasTitle || (hasDescription && !descriptionBelow) || action != null;
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start:
                    headerInset ??
                    (icon == null
                        ? 0
                        : mobile
                        ? 6
                        : 1),
                bottom: icon == null
                    ? 8
                    : mobile
                    ? 11
                    : 13,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: icon == null
                      ? 0
                      : mobile
                      ? 20
                      : 24,
                ),
                child: Row(
                  crossAxisAlignment: icon == null
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: mobile ? 18 : 19,
                        color: ColorManager.palette(context).primary,
                      ),
                      SizedBox(width: mobile ? 9 : 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasTitle)
                            Text(
                              title,
                              style:
                                  (icon == null
                                          ? AppTypography.sectionTitle
                                          : mobile
                                          ? AppTypography.settingsSectionTitle
                                          : AppTypography
                                                .settingsSectionDesktopTitle)
                                      .copyWith(
                                        color: ColorManager.primaryText(
                                          context,
                                        ),
                                      ),
                            ),
                          if (hasDescription && !descriptionBelow) ...[
                            if (hasTitle) const SizedBox(height: 3),
                            Text(
                              description!,
                              style: AppTypography.supporting.copyWith(
                                color: ColorManager.secondaryText(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (action != null) ...[const SizedBox(width: 12), action!],
                  ],
                ),
              ),
            ),
          ShadCard(
            width: double.infinity,
            padding: EdgeInsets.zero,
            radius: const BorderRadius.all(Radius.circular(AppRadii.card)),
            shadows: const [],
            clipBehavior: Clip.antiAlias,
            child: Material(type: MaterialType.transparency, child: child),
          ),
          if (hasDescription && descriptionBelow)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 10),
              child: Text(
                description!,
                style: AppTypography.settingsDetailNote.copyWith(
                  color: ColorManager.secondaryText(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
