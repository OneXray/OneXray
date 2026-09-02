import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/mixin/share.dart';
import 'package:share_plus/share_plus.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// The replies share_plus maps to its two non-success statuses.
const _dismissedReply = '';
const _unavailableReply = 'dev.fluttercommunity.plus/share/unavailable';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;

  group('positionOrigin', () {
    testWidgets('reads the rect of the render box below the context', (
      tester,
    ) async {
      late BuildContext boxContext;
      await tester.pumpWidget(
        Center(
          child: Builder(
            builder: (context) {
              boxContext = context;
              return const SizedBox(width: 120, height: 40);
            },
          ),
        ),
      );

      final origin = ContextShare.positionOrigin(boxContext);
      expect(origin, tester.getRect(find.byType(SizedBox)));
      expect(origin?.size, const Size(120, 40));
    });

    testWidgets('has no anchor for a sliver itemBuilder context', (
      tester,
    ) async {
      late BuildContext sliverContext;
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            itemCount: 1,
            itemBuilder: (context, index) {
              sliverContext = context;
              return const SizedBox(height: 40);
            },
          ),
        ),
      );

      // The itemBuilder context belongs to the sliver element, so its render
      // object is a RenderSliver. Reading it as a RenderBox is what used to
      // abort the share before it reached the platform.
      final renderObject = sliverContext.findRenderObject();
      expect(renderObject, isNotNull);
      expect(renderObject, isNot(isA<RenderBox>()));
      expect(ContextShare.positionOrigin(sliverContext), isNull);
    });

    testWidgets('has no anchor once the context is unmounted', (tester) async {
      late BuildContext boxContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              boxContext = context;
              return const SizedBox(width: 120, height: 40);
            },
          ),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(boxContext.mounted, isFalse);
      expect(ContextShare.positionOrigin(boxContext), isNull);
    });
  });

  group('share', () {
    late List<MethodCall> calls;
    late Object? reply;

    setUp(() {
      calls = <MethodCall>[];
      reply = _unavailableReply;
      messenger.setMockMethodCallHandler(_shareChannel, (call) async {
        calls.add(call);
        final answer = reply;
        if (answer is PlatformException) {
          throw answer;
        }
        return answer as String?;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(_shareChannel, null);
    });

    test('reports success when the platform names the chosen target', () async {
      reply = 'net.yuandev.onexray.receiver';

      final outcome = await ContextShare.share(ShareParams(text: 'onexray'));

      expect(outcome, ShareOutcome.success);
      expect(calls.single.method, 'share');
    });

    test('stays unconfirmed when the user dismissed the sheet', () async {
      reply = _dismissedReply;

      expect(
        await ContextShare.share(ShareParams(text: 'onexray')),
        ShareOutcome.unconfirmed,
      );
    });

    test('stays unconfirmed when the platform cannot answer', () async {
      // Windows always answers this, even after its share flyout opened, so it
      // must never be reported to the user as a failure.
      reply = _unavailableReply;

      expect(
        await ContextShare.share(ShareParams(text: 'onexray')),
        ShareOutcome.unconfirmed,
      );
    });

    test('reports a failure when the channel rejects the share', () async {
      reply = PlatformException(code: 'Share failed');

      expect(
        await ContextShare.share(ShareParams(text: 'onexray')),
        ShareOutcome.failed,
      );
      expect(calls, hasLength(1));
    });
  });
}
