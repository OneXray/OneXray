// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_core_process.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesktopCoreProcessRecord _$DesktopCoreProcessRecordFromJson(
  Map<String, dynamic> json,
) => DesktopCoreProcessRecord(
  pid: (json['pid'] as num).toInt(),
  configPath: json['configPath'] as String?,
  runtimePath: json['runtimePath'] as String?,
  startTicks: (json['startTicks'] as num?)?.toInt(),
);

Map<String, dynamic> _$DesktopCoreProcessRecordToJson(
  DesktopCoreProcessRecord instance,
) => <String, dynamic>{
  'pid': instance.pid,
  'configPath': ?instance.configPath,
  'runtimePath': ?instance.runtimePath,
  'startTicks': ?instance.startTicks,
};
