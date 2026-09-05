import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/servers/import/page.dart';

class SubscriptionEditorPage extends StatelessWidget {
  final int subscriptionId;
  const SubscriptionEditorPage({super.key, required this.subscriptionId});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        ServerImportController(subscriptionId: subscriptionId)
          ..loadSubscription(context),
    child: Builder(
      builder: (context) => ServerImportFormPage(
        controller: context.read<ServerImportController>(),
        action: ServerImportAction.subscription,
      ),
    ),
  );
}
