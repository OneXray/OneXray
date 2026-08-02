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

  group('SubscriptionInput age key pair', () {
    test('normalizes empty keys to no encryption context', () {
      const input = SubscriptionInput(
        name: 'Plain',
        url: 'https://example.com/sub',
        ageSecretKey: '   ',
        agePublicKey: '   ',
      );

      expect(input.normalizedAgeSecretKey, isNull);
      expect(input.normalizedAgePublicKey, isNull);
      expect(input.normalizedAgeContext, isNull);
      expect(input.hasIncompleteAgeKeyPair, isFalse);
    });

    test('trims and keeps a configured key pair together', () {
      const input = SubscriptionInput(
        name: 'Encrypted',
        url: 'https://example.com/sub',
        ageSecretKey: '  AGE-SECRET-KEY-1TEST  ',
        agePublicKey: '  age1test  ',
      );

      expect(input.normalizedAgeSecretKey, 'AGE-SECRET-KEY-1TEST');
      expect(input.normalizedAgePublicKey, 'age1test');
      expect(input.normalizedAgeContext?.secretKey, 'AGE-SECRET-KEY-1TEST');
      expect(input.normalizedAgeContext?.publicKey, 'age1test');
      expect(input.hasIncompleteAgeKeyPair, isFalse);
    });

    test('rejects a partial key pair', () {
      const input = SubscriptionInput(
        name: 'Encrypted',
        url: 'https://example.com/sub',
        ageSecretKey: 'AGE-SECRET-KEY-1TEST',
      );

      expect(input.hasIncompleteAgeKeyPair, isTrue);
      expect(input.normalizedAgeContext, isNull);
    });
  });

  test('SubscriptionAgeContext keeps the saved key pair together', () {
    const context = SubscriptionAgeContext(
      secretKey: 'AGE-SECRET-KEY-1TEST',
      publicKey: 'age1test',
    );

    expect(context.secretKey, 'AGE-SECRET-KEY-1TEST');
    expect(context.publicKey, 'age1test');
  });
}
