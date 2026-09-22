import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/shared/widgets/configuration_transfer.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/share/configuration_transfer.dart';

import 'test_app.dart';

void main() {
  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
  });

  for (final source in ['{\n  "outbounds": [}', 'onexray://invalid']) {
    testWidgets('import locates only original JSON: $source', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': source};
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final controller = ConfigurationTransferController(
        kind: ConfigurationKind.raw,
        readText: () => '',
        readName: () => '',
        onImport: (_) => fail('Invalid import must not replace draft'),
      );
      addTearDown(controller.close);
      await tester.pumpWidget(
        ShareTestApp(child: ConfigurationTransferTools(controller: controller)),
      );
      await controller.import(
        tester.element(find.byType(ConfigurationTransferTools)),
        clipboard: true,
      );
      await tester.pumpAndSettle();
      expect(controller.state.failed, isTrue);
      if (source.startsWith('{')) {
        expect(controller.notice, startsWith('Line 2, column '));
      } else {
        expect(controller.notice, isNot(contains('Line ')));
      }
      await tester.tap(find.text('Copy error'));
      await tester.pumpAndSettle();
      expect(copied, controller.notice);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a delayed import cannot replace newer edits', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': '{}'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final service = _PendingImport();
    var text = '';
    final controller = ConfigurationTransferController(
      kind: ConfigurationKind.raw,
      readText: () => text,
      readName: () => 'Draft',
      onImport: (draft) => text = draft.text,
      service: service,
    );
    addTearDown(controller.close);
    await tester.pumpWidget(
      ShareTestApp(child: ConfigurationTransferTools(controller: controller)),
    );
    final importing = controller.import(
      tester.element(find.byType(ConfigurationTransferTools)),
      clipboard: true,
    );
    await tester.pump();
    expect(service.started.isCompleted, isTrue);
    text = '{"newer":true}';
    service.result.complete(
      const ConfigurationImportDraft(
        ConfigurationContent(kind: ConfigurationKind.raw, text: '{}', name: ''),
        null,
      ),
    );
    await importing;
    expect(text, '{"newer":true}');
    expect(controller.imported, isNull);
    expect(controller.state.failed, isTrue);
    expect(controller.notice, isNot(contains('Line ')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PendingImport extends ConfigurationTransferService {
  final started = Completer<void>();
  final result = Completer<ConfigurationImportDraft>();

  @override
  Future<ConfigurationImportDraft> import(
    String input,
    ConfigurationKind kind,
  ) {
    started.complete();
    return result.future;
  }
}
