import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/share/backup_model.dart';

void main() {
  test('version 3 subscription data restores without an age key pair', () {
    final subscription = BackupSubscriptionJson.fromJson({
      'name': 'Legacy',
      'url': 'https://example.com/sub',
      'timestamp': 1,
      'expanded': true,
    });

    expect(subscription.ageSecretKey, isNull);
    expect(subscription.agePublicKey, isNull);
  });

  test('version 4 subscription data preserves the age key pair', () {
    const subscription = BackupSubscriptionJson(
      'Encrypted',
      'https://example.com/sub',
      'AGE-SECRET-KEY-1TEST',
      'age1test',
      1,
      true,
    );

    expect(
      BackupSubscriptionJson.fromJson(subscription.toJson()).ageSecretKey,
      'AGE-SECRET-KEY-1TEST',
    );
    expect(
      BackupSubscriptionJson.fromJson(subscription.toJson()).agePublicKey,
      'age1test',
    );
  });
}
