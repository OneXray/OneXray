import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/constants/donation.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/shared/failure.dart';

class DonationController extends PageCubit<bool> {
  DonationController() : super(false);

  Future<void> copyAddress(BuildContext context) async {
    if (state || !isPageActive) return;
    emit(true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await Clipboard.setData(const ClipboardData(text: DonationInfo.address));
      if (context.mounted && isPageActive) {
        ContextAlert.showToast(context, l10n.donationAddressCopied);
      }
    } catch (error) {
      if (context.mounted && isPageActive) {
        ContextAlert.showToast(
          context,
          appFailureMessage(
            l10n,
            error,
            operation: l10n.actionResult(
              l10n.donationCopyAddress,
              l10n.resultFailed,
            ),
          ),
        );
      }
    } finally {
      emit(false);
    }
  }
}
