import 'package:onexray/service/advanced/xray/geodata/service.dart';

/// Test adapter for the import's save/dispose interface. Real filesystem and
/// rollback behavior are exercised by Geodata publication tests.
class FakeGeoDataImport implements GeoDataImport {
  final List<String> events;
  final Future<void> Function()? writeMetadata;
  final Future<void> Function()? onDispose;

  FakeGeoDataImport({List<String>? events, this.writeMetadata, this.onDispose})
    : events = events ?? [];

  @override
  Future<T> save<T>(
    Future<T> Function(Future<void> Function() writeMetadata) action,
  ) async {
    events.add('publish');
    try {
      final result = await action(() async {
        events.add('commit');
        await writeMetadata?.call();
      });
      events.add('complete');
      return result;
    } catch (_) {
      events.add('rollback');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async => onDispose?.call();
}
