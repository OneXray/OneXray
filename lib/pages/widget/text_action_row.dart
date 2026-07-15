import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/pages/theme/font.dart';

class TextActionRow extends StatelessWidget {
  final String title;
  final String detail;
  final VoidCallback onTap;
  const TextActionRow({
    super.key,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        child: Row(
          children: [
            Text(title, style: AppTypography.rowTitle),
            const Spacer(),
            Text(detail, style: AppTypography.rowValue),
            const Icon(LucideIcons.chevronRight),
          ],
        ),
      ),
    );
  }
}
