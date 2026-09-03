import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/layout.dart';

/// Root-page title position; all typography still comes from AppBarTheme.
/// AppBarTheme has no vertical title-alignment property.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(
      0,
      MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
          ? AppSpacing.mobileHeaderContentOffset
          : 0,
    ),
    child: Text(title),
  );
}
