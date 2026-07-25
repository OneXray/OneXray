import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 5,
        horizontal: 10,
      ),
      child: Text(title, style: AppTypography.supporting),
    );
  }
}

class SectionView extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? action;
  final Widget child;

  const SectionView({
    super.key,
    required this.title,
    this.description,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.isNotEmpty;
    final hasDescription = description != null && description!.isNotEmpty;
    final hasHeader = hasTitle || hasDescription || action != null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasTitle)
                          Text(
                            title,
                            style: AppTypography.sectionTitle.copyWith(
                              color: ColorManager.primaryText(context),
                            ),
                          ),
                        if (hasDescription) ...[
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
          ShadCard(
            width: double.infinity,
            padding: EdgeInsets.zero,
            radius: const BorderRadius.all(Radius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}
