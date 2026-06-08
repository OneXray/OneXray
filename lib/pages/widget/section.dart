import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';

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
      child: Text(title, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class SectionView extends StatelessWidget {
  final String title;
  final Widget child;

  const SectionView({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.formTitle(context),
                ),
              ),
            ),
          Material(
            color: ColorManager.surface(context),
            shape: _sectionShape(context),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }

  ShapeBorder _sectionShape(BuildContext context) {
    return RoundedRectangleBorder(
      side: BorderSide(color: ColorManager.border(context), width: 1),
      borderRadius: BorderRadiusDirectional.circular(8),
    );
  }
}
