import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/shared/widgets/setting_row.dart';

class SettingsUpdateDot extends StatelessWidget {
  const SettingsUpdateDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
  );
}

class SettingsVersionRow extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;
  final TextStyle? style;
  const SettingsVersionRow({
    super.key,
    required this.label,
    required this.value,
    this.compact = false,
    this.style,
  });
  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return SettingRow(
        title: label,
        trailing: Text(
          value,
          textDirection: TextDirection.ltr,
          style: AppTypography.code,
        ),
      );
    }
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final color = ColorManager.palette(context).mutedStrong;
    return SettingRow(
      title: label,
      minHeight: mobile ? 42 : 53,
      contentPadding: EdgeInsetsDirectional.symmetric(
        horizontal: mobile ? 13 : 14,
        vertical: 8,
      ),
      titleStyle: (style ?? AppTypography.settingsVersion).copyWith(
        color: color,
      ),
      trailing: Text(
        value,
        textDirection: TextDirection.ltr,
        style: (style ?? AppTypography.settingsVersion).copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
