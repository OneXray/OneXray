import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';

class SubscriptionAddController extends Cubit<int> {
  SubscriptionAddController() : super(0);

  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Future<void> close() {
    nameController.dispose();
    urlController.dispose();
    return super.close();
  }

  Future<void> save(BuildContext context) async {
    final name = nameController.text.removeWhitespace;
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
}
