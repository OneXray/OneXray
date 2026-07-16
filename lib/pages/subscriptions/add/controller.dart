import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';

class SubscriptionAddPageState {
  const SubscriptionAddPageState({required this.autoUpdateState});

  factory SubscriptionAddPageState.initial() =>
      SubscriptionAddPageState(autoUpdateState: AutoUpdateState());

  final AutoUpdateState autoUpdateState;
}

class SubscriptionAddController extends PageCubit<SubscriptionAddPageState> {
  SubscriptionAddController() : super(SubscriptionAddPageState.initial()) {
    _readAutoUpdateState();
  }

  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
    urlController.dispose();
  }

  Future<void> save(BuildContext context) async {
    final name = nameController.text.trim();
    final url = urlController.text.removeWhitespace;
    final check = await SubscriptionValidator.validate(name, url);
    if (check.item1) {
      final count = await SubscriptionService().insertSubscription(
        name,
        url,
        true,
      );
      if (context.mounted) {
        if (count > 0) {
          context.pop();
        } else {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.buttonAddFailed,
          );
        }
      }
    } else {
      if (context.mounted) {
        ContextAlert.showToast(context, check.item2);
      }
    }
  }

  Future<void> gotoAutoUpdate(BuildContext context) async {
    await context.pushScoped(AppSecondaryDestination.autoUpdate);
    await _readAutoUpdateState();
  }

  Future<void> _readAutoUpdateState() async {
    final autoUpdateState = AutoUpdateState();
    await autoUpdateState.readFromPreferences();
    if (isPageActive) {
      emit(SubscriptionAddPageState(autoUpdateState: autoUpdateState));
    }
  }
}
