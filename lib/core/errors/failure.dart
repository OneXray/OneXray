import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

enum FailureCategory {
  input,
  configuration,
  network,
  permission,
  storage,
  conflict,
  runtime,
  unknown,
}

/// Adds business context without replacing the original failure.
class AppFailure implements Exception {
  final FailureCategory category;
  final String code;
  final Object? cause;

  const AppFailure(this.category, this.code, {this.cause});

  @override
  String toString() =>
      failureDetails(cause).isEmpty ? code : '$code: ${failureDetails(cause)}';
}

FailureCategory failureCategory(Object? error) => switch (error) {
  AppFailure() => error.category,
  DioException() ||
  SocketException() ||
  HttpException() ||
  HandshakeException() ||
  TimeoutException() => FailureCategory.network,
  FileSystemException() || SqliteException() => FailureCategory.storage,
  FormatException() => FailureCategory.input,
  _ => FailureCategory.unknown,
};

/// Diagnostic text, not a dump of request bodies, SQL arguments or JSON source.
/// Xray's own diagnostic text is kept verbatim.
String failureDetails(Object? error) => switch (error) {
  null => '',
  AppFailure(code: 'cleanupBeforeDelete') =>
    '${failureDetails(error.cause)}\nNo app data was deleted.',
  AppFailure() =>
    error.cause != null
        ? failureDetails(error.cause)
        : switch (error.code) {
            'changed' || 'configurationChanged' => 'The configuration changed during this operation. Reopen it and try again.',
            'missing' || 'notFound' => 'The requested item no longer exists.',
            _ => '',
          },
  DioException() => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Request timed out (${error.type.name})',
    DioExceptionType.badResponse =>
      'HTTP ${error.response?.statusCode ?? "error"}',
    DioExceptionType.cancel => '',
    _ =>
      failureDetails(error.error).isNotEmpty
          ? failureDetails(error.error)
          : error.type.name,
  },
  FormatException() =>
    error.offset == null
        ? error.message
        : '${error.message} (offset ${error.offset})',
  FileSystemException() => [
    error.message,
    if (error.osError != null) error.osError.toString(),
    if (error.path?.isNotEmpty == true) error.path!,
  ].join(': '),
  SqliteException() => 'SQLite ${error.extendedResultCode}: ${error.message}',
  HttpException() => error.message,
  PlatformException() =>
    '${error.code}: ${error.message ?? error.details ?? ""}',
  StateError() => error.message,
  ArgumentError() => '${error.message ?? error.name ?? "Invalid argument"}',
  _ => error.toString(),
};

bool failureCancelled(Object? error) =>
    error is DioException && error.type == DioExceptionType.cancel ||
    error is AppFailure && error.code == 'cancelled';
