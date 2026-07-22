import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/share/service.dart';

void main() {
  group('ShareService.parseSubscriptionImportEntries', () {
    test('removes the fragment and keeps it as the subscription name', () {
      final entries = ShareService.parseSubscriptionImportEntries(
        'https://example.com/sub?token=123#Global%20Premium',
      );

      expect(entries, hasLength(1));
      expect(entries.single.url, 'https://example.com/sub?token=123');
      expect(entries.single.name, 'Global Premium');
    });

    test('parses one HTTPS subscription per non-empty line', () {
      final entries = ShareService.parseSubscriptionImportEntries('''
https://example.com/first#First

  https://example.com/second?token=2#Second  
https://example.com/third
''');

      expect(entries.map((entry) => entry.url), <String>[
        'https://example.com/first',
        'https://example.com/second?token=2',
        'https://example.com/third',
      ]);
      expect(entries.map((entry) => entry.name), <String>[
        'First',
        'Second',
        '',
      ]);
    });

    test(
      'ignores invalid and non-HTTPS lines without changing valid lines',
      () {
        final entries = ShareService.parseSubscriptionImportEntries('''
https://example.com/first#First
not-a-link
http://example.com/insecure
https://
https://example.com/last#Last
''');

        expect(entries.map((entry) => entry.url), <String>[
          'https://example.com/first',
          'https://example.com/last',
        ]);
      },
    );
  });
}
