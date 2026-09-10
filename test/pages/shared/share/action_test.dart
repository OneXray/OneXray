import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/shared/share/action.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/service/shared/share/outgoing_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'test_app.dart';

const _content = ShareText(title: 'Example', text: 'onexray://example.test');
const _buttonKey = Key('share-button');

Widget _button(BuildContext context, ShareActionView action) =>
    ConnectDialogButton(
      key: _buttonKey,
      label: action.label,
      icon: action.icon,
      busy: action.busy,
      onPressed: action.onPressed,
    );

OutgoingShare _native(Future<ShareResult> Function(ShareParams) send) =>
    OutgoingShare(
      destination: ShareDestination.system,
      platform: SharePlus.custom(FakeSharePlatform(send)),
      writeClipboard: (_) async => fail('Native results must not copy'),
    );

void main() {
  for (final status in ShareResultStatus.values) {
    testWidgets('native $status is quiet and keeps the current route', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final calls = <ShareParams>[];
      await tester.pumpWidget(
        ShareTestApp(navigatorKey: navigator, child: const Text('Home')),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Center(
                child: ShareAction(
                  prepare: () => _content,
                  outgoing: _native((params) async {
                    calls.add(params);
                    return ShareResult('synthetic', status);
                  }),
                  builder: _button,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(_buttonKey));
      await tester.tap(find.byKey(_buttonKey));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.sharePositionOrigin, rect);
      expect(find.byKey(_buttonKey), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
      expect(find.byType(ShadToast), findsNothing);
      expect(find.byType(ButtonProgressIndicator), findsNothing);
    });
  }

  testWidgets('duplicate requests are local and other controls remain usable', (
    tester,
  ) async {
    final result = Completer<ShareResult>();
    var calls = 0;
    var otherCalls = 0;
    late VoidCallback firstPress;
    await tester.pumpWidget(
      ShareTestApp(
        child: Column(
          children: [
            ShareAction(
              prepare: () => _content,
              outgoing: _native((_) {
                calls++;
                return result.future;
              }),
              builder: (context, action) {
                if (!action.busy) firstPress = action.onPressed!;
                return _button(context, action);
              },
            ),
            TextButton(
              onPressed: () => otherCalls++,
              child: const Text('Other'),
            ),
          ],
        ),
      ),
    );
    firstPress();
    firstPress();
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(ButtonProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Other'));
    expect(otherCalls, 1);
    result.complete(ShareResult.unavailable);
    await tester.pumpAndSettle();
    expect(find.byType(ButtonProgressIndicator), findsNothing);
  });

  testWidgets('a second action does not wait for another native request', (
    tester,
  ) async {
    final first = Completer<ShareResult>();
    var calls = 0;
    final outgoing = _native((_) {
      calls++;
      return calls == 1 ? first.future : Future.value(ShareResult.unavailable);
    });
    await tester.pumpWidget(
      ShareTestApp(
        child: Column(
          children: [
            for (var i = 0; i < 2; i++)
              ShareAction(
                prepare: () => _content,
                outgoing: outgoing,
                builder: (_, action) => TextButton(
                  onPressed: action.onPressed,
                  child: Text('Share $i'),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Share 0'));
    await tester.pump();
    await tester.tap(find.text('Share 1'));
    await tester.pump();
    expect(calls, 2);
    first.complete(ShareResult.unavailable);
    await tester.pumpAndSettle();
  });

  testWidgets('invocation errors show their cause and allow retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShareTestApp(
        child: ShareAction(
          prepare: () => _content,
          outgoing: _native(
            (_) async => throw PlatformException(
              code: 'no_window',
              message: 'No foreground window',
            ),
          ),
          builder: _button,
        ),
      ),
    );
    await tester.tap(find.byKey(_buttonKey));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('no_window: No foreground window'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.byType(ButtonProgressIndicator), findsNothing);
  });

  testWidgets('Linux copy has copy wording, icon and a two-second toast', (
    tester,
  ) async {
    final copied = <String>[];
    await tester.pumpWidget(
      ShareTestApp(
        child: ShareAction(
          prepare: () => _content,
          outgoing: OutgoingShare(
            destination: ShareDestination.clipboard,
            writeClipboard: (text) async => copied.add(text),
          ),
          builder: _button,
        ),
      ),
    );
    expect(find.text('Copy share link'), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.byIcon(LucideIcons.share2), findsNothing);
    await tester.tap(find.byKey(_buttonKey));
    await tester.pumpAndSettle();
    expect(copied, [_content.text]);
    expect(
      tester.widget<ShadToast>(find.byType(ShadToast)).duration,
      const Duration(seconds: 2),
    );
    expect(find.byKey(_buttonKey), findsOneWidget);
  });

  testWidgets('canceling the sensitive-content warning does not dispatch', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ShareTestApp(
        child: ShareAction(
          prepare: () => _content,
          warning: 'Synthetic sensitive content warning',
          outgoing: _native((_) async {
            calls++;
            return ShareResult.unavailable;
          }),
          builder: _button,
        ),
      ),
    );
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Synthetic sensitive content warning'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(ButtonProgressIndicator), findsNothing);
    expect(find.byType(ShadToast), findsNothing);
  });

  testWidgets('closing during preparation prevents a later native invocation', (
    tester,
  ) async {
    final prepared = Completer<ShareText>();
    var calls = 0;
    await tester.pumpWidget(
      ShareTestApp(
        child: ShareAction(
          prepare: () => prepared.future,
          outgoing: _native((_) async {
            calls++;
            return ShareResult.unavailable;
          }),
          builder: _button,
        ),
      ),
    );
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();
    await tester.pumpWidget(const ShareTestApp(child: Text('Closed')));
    prepared.complete(_content);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing does not await native sharing or show late errors', (
    tester,
  ) async {
    final result = Completer<ShareResult>();
    await tester.pumpWidget(
      ShareTestApp(
        child: ShareAction(
          prepare: () => _content,
          outgoing: _native((_) => result.future),
          builder: _button,
        ),
      ),
    );
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();
    await tester.pumpWidget(const ShareTestApp(child: Text('Closed')));
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    result.completeError(PlatformException(code: 'late_error'));
    await tester.pumpAndSettle();
    expect(find.byType(ShadToast), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final hiddenByRoute in [false, true]) {
    testWidgets('hidden ${hiddenByRoute ? 'route' : 'tab'} stops preparation', (
      tester,
    ) async {
      final prepared = Completer<ShareText>();
      final navigator = GlobalKey<NavigatorState>();
      var calls = 0;
      final action = ShareAction(
        prepare: () => prepared.future,
        outgoing: _native((_) async {
          calls++;
          return ShareResult.unavailable;
        }),
        builder: _button,
      );
      Widget host(bool visible) => ShareTestApp(
        navigatorKey: navigator,
        child: TickerMode(enabled: visible, child: action),
      );
      await tester.pumpWidget(host(true));
      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();
      if (hiddenByRoute) {
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Other page')),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        await tester.pumpWidget(host(false));
      }
      prepared.complete(_content);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(ShadToast), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the actual button is measured after asynchronous preparation', (
    tester,
  ) async {
    final prepared = Completer<ShareText>();
    late ShareParams sent;
    final action = ShareAction(
      prepare: () => prepared.future,
      outgoing: _native((params) async {
        sent = params;
        return ShareResult.unavailable;
      }),
      builder: _button,
    );
    Widget host(double gap) => ShareTestApp(
      child: ListView.builder(
        itemCount: 2,
        itemBuilder: (_, index) => index == 0
            ? SizedBox(height: gap)
            : Align(alignment: Alignment.centerLeft, child: action),
      ),
    );
    await tester.pumpWidget(host(10));
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();
    await tester.pumpWidget(host(100));
    final rect = tester.getRect(find.byKey(_buttonKey));
    prepared.complete(_content);
    await tester.pumpAndSettle();
    expect(sent.sharePositionOrigin, rect);
    expect(rect.top, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty anchor falls back to native positioning', (
    tester,
  ) async {
    late VoidCallback press;
    late ShareParams sent;
    await tester.pumpWidget(
      ShareTestApp(
        child: Center(
          child: ShareAction(
            prepare: () => _content,
            outgoing: _native((params) async {
              sent = params;
              return ShareResult.unavailable;
            }),
            builder: (_, action) {
              if (action.onPressed != null) press = action.onPressed!;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    press();
    await tester.pumpAndSettle();
    expect(sent.sharePositionOrigin, isNull);
    expect(tester.takeException(), isNull);
  });
}
