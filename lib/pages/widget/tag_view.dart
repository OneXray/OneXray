import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';

class TagView extends StatelessWidget {
  final String tag;

  const TagView({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: ColorManager.tagBackground(context),
        shape: StadiumBorder(
          side: BorderSide(color: ColorManager.border(context), width: 1),
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 2,
        horizontal: 6,
      ),
      margin: const EdgeInsetsDirectional.only(end: 4),
      child: Text(
        tag,
        style: AppTypography.badge.copyWith(
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }
}
