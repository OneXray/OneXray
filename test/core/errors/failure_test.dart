import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/connect/failure.dart';
import 'package:onexray/service/connect/runtime_host.dart';
import 'package:onexray/service/servers/subscription/failure.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/shared/failure.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('zh'));

  test('Xray validation detail survives presentation unchanged', () {
    const detail = 'app/router: balancer proxy not found';
    const error = AppFailure(
      FailureCategory.configuration,
      'xrayValidation',
      cause: detail,
    );
    expect(failureCategory(error), FailureCategory.configuration);
    expect(connectionFailureMessage(l, error: error), contains(detail));
    expect(
      connectionFailureMessage(l, error: error),
      isNot(contains(l.prototypeCheckNetwork)),
    );
  });

  test('HTTP failures keep the status, not request credentials', () {
    final options = RequestOptions(
      path: 'https://example.com/sub?token=secret',
    );
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: 403),
    );
    expect(failureCategory(error), FailureCategory.network);
    final message = subscriptionFailureMessage(
      l,
      SubscriptionUpdateResult.downloadFailed,
      error: error,
    );
    expect(message, contains('HTTP 403'));
    expect(message, isNot(contains('token=secret')));
  });

  test('JSON diagnostics exclude the source while preserving position', () {
    const error = FormatException('Unexpected character', '{secret}', 3);
    expect(failureDetails(error), 'Unexpected character (offset 3)');
  });

  test('local I/O is not classified as a network failure', () {
    const error = FileSystemException('Delete failed', '/data/other.dat');
    expect(failureCategory(error), FailureCategory.storage);
    expect(appFailureMessage(l, error), contains('other.dat'));
    expect(
      appFailureMessage(l, error),
      isNot(contains(l.prototypeCheckNetwork)),
    );
  });

  test('native errors and timeout operations remain distinguishable', () {
    expect(
      connectionFailureMessage(
        l,
        error: const ConnectionHostException(
          'startFailed',
          cause: 'Permission denied',
        ),
      ),
      contains('Permission denied'),
    );
    expect(
      connectionFailureMessage(
        l,
        error: const ConnectionHostException('startTimeout'),
      ),
      '${l.prototypeConnect} · ${l.prototypeTimeout}',
    );
    expect(
      connectionFailureMessage(
        l,
        error: const ConnectionHostException('stopTimeout'),
      ),
      '${l.prototypeDisconnect} · ${l.prototypeTimeout}',
    );
    expect(
      failureCategory(TimeoutException('Download timed out')),
      FailureCategory.network,
    );
  });

  test(
    'unknown failures and cancellation are not guessed to be network failures',
    () {
      expect(
        connectionFailureMessage(l, error: StateError('Database closed')),
        contains('Database closed'),
      );
      expect(
        connectionFailureMessage(l, error: StateError('Database closed')),
        isNot(contains(l.prototypeCheckNetwork)),
      );
      expect(
        failureCancelled(
          const AppFailure(FailureCategory.conflict, 'cancelled'),
        ),
        isTrue,
      );
    },
  );

  test('update failures do not claim the subscription was not added', () {
    final message = subscriptionFailureMessage(
      l,
      SubscriptionUpdateResult.invalidContent,
      updating: true,
    );
    expect(message, l.prototypeNoAvailableEntries);
    expect(message, isNot(contains('未添加')));
  });

  test('cleanup keeps the failed stop phase and only promises no deletion before it', () {
    const cause = ConnectionHostException('stopFailed', cause: 'Access denied');
    final before = appFailureMessage(
      l,
      const AppFailure(
        FailureCategory.runtime,
        'cleanupBeforeDelete',
        cause: cause,
      ),
    );
    expect(before, contains(l.prototypeDisconnect));
    expect(before, contains('Access denied'));
    expect(before, contains('No app data was deleted.'));
    final during = appFailureMessage(
      l,
      const AppFailure(
        FailureCategory.storage,
        'cleanup',
        cause: FileSystemException('Permission denied', '/data/cache'),
      ),
    );
    expect(during, contains('/data/cache'));
    expect(during, isNot(contains('No app data was deleted.')));
  });

  test(
    'missing subscription explains the conflict without blaming the network',
    () {
      final message = subscriptionFailureMessage(
        l,
        SubscriptionUpdateResult.notFound,
        updating: true,
      );
      expect(message, contains('no longer exists'));
      expect(message, isNot(contains(l.prototypeCheckNetwork)));
    },
  );
}
