import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A full-page footer. Use as Scaffold.bottomNavigationBar, not inside a scroll
/// view. Dialogs own their actions and do not use this component.
class PageActionBar extends StatelessWidget {
  const PageActionBar({
    super.key,
    required this.children,
    this.horizontalPadding,
    this.spacing = AppSpacing.actionGap,
  });

  final List<Widget> children;
  final double? horizontalPadding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final minHeight = mobile
        ? AppLayout.mobilePageActionMinHeight
        : AppLayout.pageActionMinHeight;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.standardMaxWidth,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        horizontalPadding ??
                        (mobile ? AppSpacing.mobilePage : AppSpacing.page),
                    vertical:
                        (minHeight - AppLayout.pageActionButtonMinHeight) / 2,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: mobile
                        ? Theme(
                            data: AppTheme.pageActions(context),
                            child: ShadTheme(
                              data: AppTheme.pageActionsShad(context),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  for (
                                    var index = 0;
                                    index < children.length;
                                    index++
                                  ) ...[
                                    if (index > 0) SizedBox(width: spacing),
                                    Expanded(child: children[index]),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : Wrap(
                            alignment: WrapAlignment.end,
                            spacing: spacing,
                            runSpacing: AppSpacing.actionRunGap,
                            children: [
                              for (final child in children)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: mobile
                                        ? 0
                                        : AppLayout.pageActionButtonMinWidth,
                                    minHeight:
                                        AppLayout.pageActionButtonMinHeight,
                                  ),
                                  child: child,
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
