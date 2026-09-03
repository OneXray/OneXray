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
    expect(subscription.count, isNull);
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
      const custom = BackupCustomRoutingProfileJson(
        4,
        'Custom',
        'eyJvdXRib3VuZHMiOlt7fV19',
      );
      expect(
        BackupCustomRoutingProfileJson.fromJson(custom.toJson()).toJson(),
        custom.toJson(),
      );
      const subscription = BackupSubscriptionJson(
        'Sub',
        'https://example.com/sub',
        'secret',
        'public',
        1000,
        true,
        id: 7,
        count: 1,
      );
      expect(
        BackupSubscriptionJson.fromJson(subscription.toJson()).toJson(),
        subscription.toJson(),
      );
    },
  );

  test('retired probe and parse metadata is ignored and never exported', () {
    final node = BackupCoreConfigJson.fromJson({
      'name': 'Node',
      'type': 'outbound',
      'delay': 30,
      'locationSource': 'pingBatch',
      'lastMeasuredAt': 1000,
    });
    expect(node.toJson(), {'name': 'Node', 'type': 'outbound', 'delay': 30});
    final subscription = BackupSubscriptionJson.fromJson({
      'name': 'Sub',
      'parseFailureCount': 2,
      'autoUpdate': false,
    });
    expect(subscription.toJson(), {'name': 'Sub', 'autoUpdate': false});
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
