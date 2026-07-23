import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';

class DateView extends StatelessWidget {
  final DateTime date;

  const DateView({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMd(localeName).add_Hms().format(date);
    final style = AppTypography.supporting.copyWith(
      color: ColorManager.secondaryText(context),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.dateViewLastUpdateTime,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          Text(
            dateStr,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ),
    );
  }
}
