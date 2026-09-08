import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/advanced/policy_editor.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  for (final outcome in ['saved', 'cancelled', 'failed']) {
    testWidgets('tunnel save feedback: $outcome', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      final service = _PendingSave(coordinator);
      final controller = PolicyEditorController(
        draft: await service.load(),
        service: service,
      );
      addTearDown(() async {
        await controller.close();
        coordinator.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalePolicy.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ShadTheme(
            data: AppTheme.shad(Brightness.light),
            child: ShadToaster(child: child!),
          ),
          home: BlocBuilder<PolicyEditorController, PolicyEditorPageState>(
            bloc: controller,
            builder: (context, state) => Scaffold(
              body: const Text('Tunnel'),
              bottomNavigationBar: PolicyActions(
                controller: controller,
                cancel: () {},
                cancelLabel: 'Cancel',
                save: () => controller.save(context, pop: false),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.byType(ButtonProgressIndicator), findsOneWidget);
      expect(find.byType(ShadToast), findsNothing);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );

      if (outcome == 'failed') {
        service.result.completeError(StateError('Save failed'));
      } else {
        service.result.complete(outcome == 'saved');
      }
      await tester.pumpAndSettle();
      expect(controller.busy, isFalse);
      expect(find.byType(ButtonProgressIndicator), findsNothing);
      expect(
        find.text('Settings saved'),
        outcome == 'saved' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Save failed'),
        outcome == 'failed' ? findsOneWidget : findsNothing,
      );
      expect(find.text('Tunnel'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _PendingSave extends PolicyEditorService {
  _PendingSave(ConnectionCoordinator coordinator)
    : super(coordinator: coordinator, platform: ConnectionPlatform.ios);

  final result = Completer<bool>();

  @override
  Future<PolicyEditorDraft> load() async =>
      PolicyEditorDraft(ConnectionConfiguration());

  @override
  Future<bool> save({
    required PolicyEditorDraft draft,
    required Future<bool> Function(bool disconnect) confirm,
  }) => result.future;
}
