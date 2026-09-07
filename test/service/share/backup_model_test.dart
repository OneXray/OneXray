import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/share/backup_model.dart';

void main() {
  test('writes v5 while continuing to accept v3 and v4', () {
    expect(BackupManifestJson.currentVersion, 5);
    expect(BackupManifestJson.supportedVersions, {3, 4, 5});
  });

  test('version 3 subscription data restores without an age key pair', () {
    final subscription = BackupSubscriptionJson.fromJson({
      'name': 'Legacy',
      'url': 'https://example.com/sub',
      'timestamp': 1,
      'expanded': true,
    });

    expect(subscription.ageSecretKey, isNull);
    expect(subscription.agePublicKey, isNull);
    expect(subscription.id, isNull);
  });

  test(
    'v5 DTOs retain IDs, metadata, and base64 bytes without re-encoding',
    () {
      const node = BackupCoreConfigJson(
        'Node',
        'outbound',
        'VLESS',
        'eyJ0YWciOiJOb2RlIn0=',
        id: 11,
        subId: 7,
        delay: 30,
        countryCode: 'JP',
        favorite: true,
      );
      expect(
        BackupCoreConfigJson.fromJson(node.toJson()).toJson(),
        node.toJson(),
      );
      const custom = BackupRoutingProfileJson(
        4,
        'Custom',
        'eyJvdXRib3VuZHMiOlt7fV19',
      );
      expect(
        BackupRoutingProfileJson.fromJson(custom.toJson()).toJson(),
        custom.toJson(),
      );
      const subscription = BackupSubscriptionJson(
        'Sub',
        'https://example.com/sub',
        'secret',
        'public',
        1000,
        id: 7,
      );
      expect(subscription.toJson(), isNot(contains('autoUpdate')));
      expect(subscription.toJson(), isNot(contains('count')));
      expect(subscription.toJson(), isNot(contains('expanded')));
      expect(
        BackupSubscriptionJson.fromJson(subscription.toJson()).toJson(),
        subscription.toJson(),
      );
    },
  );

  test('version 4 subscription data preserves the age key pair', () {
    const subscription = BackupSubscriptionJson(
      'Encrypted',
      'https://example.com/sub',
      'AGE-SECRET-KEY-1TEST',
      'age1test',
      1,
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
