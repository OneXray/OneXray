import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';

class BottomView extends StatelessWidget {
  final Widget child;

  const BottomView({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorManager.surface(context),
      padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
      child: child,
    );
  }
}
