import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';

class DateView extends StatelessWidget {
  final DateTime date;

  const DateView({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("yyyy-MM-dd HH:mm:ss").format(date);
    return Padding(
      padding: EdgeInsetsDirectional.only(top: 4),
      child: Text(
        "${AppLocalizations.of(context)!.dateViewLastUpdateTime} $dateStr",
        style: TextStyle(
          fontSize: 11,
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }
}
