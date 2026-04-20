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

enum SectionLevel { first, second, none }

class SectionView extends StatelessWidget {
  final String title;
  final Widget child;
  final SectionLevel level;

  const SectionView({
    super.key,
    required this.title,
    required this.child,
    this.level = SectionLevel.first,
  });

  @override
  Widget build(BuildContext context) {
    switch (level) {
      case SectionLevel.first:
        return _buildFirstSection(context);
      case SectionLevel.second:
        return _buildSecondSection(context);
      case SectionLevel.none:
        return _buildNoneSection(context);
    }
  }

  Widget _buildFirstSection(BuildContext context) {
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

          Container(
            padding: EdgeInsetsDirectional.all(16),
            decoration: ShapeDecoration(
              color: ColorManager.surface(context),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: ColorManager.border(context), width: 1),
                borderRadius: BorderRadiusDirectional.circular(8),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSecondSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ColorManager.formTitle(context),
              ),
            ),
          ),
        child,
      ],
    );
  }

  Widget _buildNoneSection(BuildContext context) {
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
          Container(
            decoration: ShapeDecoration(
              color: ColorManager.surface(context),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: ColorManager.border(context), width: 1),
                borderRadius: BorderRadiusDirectional.circular(8),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
