import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/subscription/model.dart';

void main() {
  group('SubscriptionUrl.normalize', () {
    test('removes whitespace and URL fragment', () {
      expect(
        SubscriptionUrl.normalize(
          ' https://example.com/sub?token=123#Subscription Name ',
        ),
        'https://example.com/sub?token=123',
      );
    });

    test('preserves encoded fragment characters', () {
      expect(
        SubscriptionUrl.normalize(
          'https://example.com/sub?value=encoded%23value',
        ),
        'https://example.com/sub?value=encoded%23value',
      );
    });
  });
}
