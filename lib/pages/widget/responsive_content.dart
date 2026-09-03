import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/layout.dart';

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double desktopMaxWidth;
  final double adaptiveBreakpoint;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.desktopMaxWidth = AppLayout.standardMaxWidth,
    this.adaptiveBreakpoint = AppLayout.contentBreakpoint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= adaptiveBreakpoint
            ? desktopMaxWidth
            : double.infinity;
        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        );
      },
    );
  }
}
