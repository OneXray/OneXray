import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/share/outgoing_share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

void main() {
  const content = ShareText(
    title: '  Example  ',
    text: 'onexray://example.test/first\nonexray://example.test/second\n',
  );
  const origin = Rect.fromLTWH(10, 20, 100, 40);

  for (final status in ShareResultStatus.values) {
    test(
      'native $status preserves content without copying or retrying',
      () async {
        final calls = <ShareParams>[];
        final clipboard = <String>[];
        final share = OutgoingShare(
          destination: ShareDestination.system,
          platform: SharePlus.custom(
            _Platform((params) async {
              calls.add(params);
              return ShareResult('synthetic', status);
            }),
          ),
          writeClipboard: (text) async => clipboard.add(text),
        );
        await share.sendText(content, origin: origin);
        expect(calls, hasLength(1));
        expect(calls.single.text, content.text);
        expect(calls.single.title, 'Example');
        expect(calls.single.subject, 'Example');
        expect(calls.single.sharePositionOrigin, origin);
        expect(calls.single.uri, isNull);
        expect(calls.single.files, isNull);
        expect(clipboard, isEmpty);
      },
    );
  }

  test('empty names use nonempty metadata without changing text', () async {
    late ShareParams sent;
    final share = OutgoingShare(
      destination: ShareDestination.system,
      platform: SharePlus.custom(
        _Platform((params) async {
          sent = params;
          return ShareResult.unavailable;
        }),
      ),
    );
    await share.sendText(const ShareText(title: '  ', text: ' exact text '));
    expect(sent.title, 'OneXray');
    expect(sent.subject, 'OneXray');
    expect(sent.text, ' exact text ');
    expect(sent.sharePositionOrigin, isNull);
  });

  test('native exceptions keep their identity and never copy', () async {
    final error = PlatformException(code: 'synthetic', message: 'No window');
    var copied = false;
    final share = OutgoingShare(
      destination: ShareDestination.system,
      platform: SharePlus.custom(_Platform((_) async => throw error)),
      writeClipboard: (_) async => copied = true,
    );
    await expectLater(share.sendText(content), throwsA(same(error)));
    expect(copied, isFalse);
  });

  test('explicit clipboard destination bypasses native sharing', () async {
    final clipboard = <String>[];
    final share = OutgoingShare(
      destination: ShareDestination.clipboard,
      platform: SharePlus.custom(
        _Platform((_) async {
          fail('Native sharing must not run for clipboard dispatch');
        }),
      ),
      writeClipboard: (text) async => clipboard.add(text),
    );
    await share.sendText(content);
    expect(clipboard, [content.text]);
  });

  test('clipboard exceptions propagate', () async {
    final error = StateError('Synthetic clipboard failure');
    final share = OutgoingShare(
      destination: ShareDestination.clipboard,
      writeClipboard: (_) async => throw error,
    );
    await expectLater(share.sendText(content), throwsA(same(error)));
  });

  test('empty text cannot clear the clipboard', () async {
    var copied = false;
    final share = OutgoingShare(
      destination: ShareDestination.clipboard,
      writeClipboard: (_) async => copied = true,
    );
    await expectLater(
      share.sendText(const ShareText(title: '', text: '')),
      throwsArgumentError,
    );
    expect(copied, isFalse);
  });
}

class _Platform extends SharePlatform {
  _Platform(this.send);
  final Future<ShareResult> Function(ShareParams) send;

  @override
  Future<ShareResult> share(ShareParams params) => send(params);
}
