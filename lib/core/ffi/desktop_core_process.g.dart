// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_core_process.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesktopCoreProcessRecord _$DesktopCoreProcessRecordFromJson(
  Map<String, dynamic> json,
) => DesktopCoreProcessRecord(
  pid: (json['pid'] as num).toInt(),
  executablePath: json['executablePath'] as String,
  mode: $enumDecode(_$DesktopCoreModeEnumMap, json['mode']),
);

Map<String, dynamic> _$DesktopCoreProcessRecordToJson(
  DesktopCoreProcessRecord instance,
) => <String, dynamic>{
  'pid': instance.pid,
  'executablePath': instance.executablePath,
  'mode': _$DesktopCoreModeEnumMap[instance.mode]!,
};

const _$DesktopCoreModeEnumMap = {
  DesktopCoreMode.tun: 'tun',
  DesktopCoreMode.proxy: 'proxy',
};
