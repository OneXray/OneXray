import 'package:flutter/material.dart';
import 'package:onexray/core/tools/platform.dart';

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double desktopMaxWidth;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.desktopMaxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = AppPlatform.isDesktop ? desktopMaxWidth : double.infinity;
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
