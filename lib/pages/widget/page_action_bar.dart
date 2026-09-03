import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/layout.dart';

/// A full-page footer. Use as Scaffold.bottomNavigationBar, not inside a scroll
/// view. Dialogs own their actions and do not use this component.
class PageActionBar extends StatelessWidget {
  const PageActionBar({super.key, required this.children});

  final List<Widget> children;

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
                minimum: EdgeInsets.symmetric(
                  horizontal: mobile ? AppSpacing.mobilePage : AppSpacing.page,
                  vertical:
                      (minHeight - AppLayout.pageActionButtonMinHeight) / 2,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.actionGap,
                    runSpacing: AppSpacing.actionRunGap,
                    children: [
                      for (final child in children)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: mobile
                                ? 0
                                : AppLayout.pageActionButtonMinWidth,
                            minHeight: AppLayout.pageActionButtonMinHeight,
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
    );
  }
}
