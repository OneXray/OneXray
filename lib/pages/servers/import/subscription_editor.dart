import 'package:flutter/material.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/servers/import/page.dart';

class SubscriptionEditorPage extends StatefulWidget {
  final int subscriptionId;
  const SubscriptionEditorPage({super.key, required this.subscriptionId});

  @override
  State<SubscriptionEditorPage> createState() => _SubscriptionEditorPageState();
}

class _SubscriptionEditorPageState extends State<SubscriptionEditorPage> {
  late final controller = ServerImportController(
    subscriptionId: widget.subscriptionId,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.loadSubscription(context);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ServerImportFormPage(
    controller: controller,
    action: ServerImportAction.subscription,
  );
}
