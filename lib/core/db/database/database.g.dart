// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CoreConfigTable extends CoreConfig
    with TableInfo<$CoreConfigTable, CoreConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoreConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _delayMeta = const VerificationMeta('delay');
  @override
  late final GeneratedColumn<int> delay = GeneratedColumn<int>(
    'delay',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subIdMeta = const VerificationMeta('subId');
  @override
  late final GeneratedColumn<int> subId = GeneratedColumn<int>(
    'sub_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    tags,
    data,
    delay,
    subId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'core_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoreConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('delay')) {
      context.handle(
        _delayMeta,
        delay.isAcceptableOrUnknown(data['delay']!, _delayMeta),
      );
    } else if (isInserting) {
      context.missing(_delayMeta);
    }
    if (data.containsKey('sub_id')) {
      context.handle(
        _subIdMeta,
        subId.isAcceptableOrUnknown(data['sub_id']!, _subIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoreConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoreConfigData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      ),
      delay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delay'],
      )!,
      subId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sub_id'],
      )!,
    );
  }

  @override
  $CoreConfigTable createAlias(String alias) {
    return $CoreConfigTable(attachedDatabase, alias);
  }
}

class CoreConfigData extends DataClass implements Insertable<CoreConfigData> {
  final int id;
  final String name;
  final String type;
  final String tags;
  final String? data;
  final int delay;
  final int subId;
  const CoreConfigData({
    required this.id,
    required this.name,
    required this.type,
    required this.tags,
    this.data,
    required this.delay,
    required this.subId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    map['delay'] = Variable<int>(delay);
    map['sub_id'] = Variable<int>(subId);
    return map;
  }

  CoreConfigCompanion toCompanion(bool nullToAbsent) {
    return CoreConfigCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      tags: Value(tags),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
      delay: Value(delay),
      subId: Value(subId),
    );
  }

  factory CoreConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoreConfigData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      tags: serializer.fromJson<String>(json['tags']),
      data: serializer.fromJson<String?>(json['data']),
      delay: serializer.fromJson<int>(json['delay']),
      subId: serializer.fromJson<int>(json['subId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'tags': serializer.toJson<String>(tags),
      'data': serializer.toJson<String?>(data),
      'delay': serializer.toJson<int>(delay),
      'subId': serializer.toJson<int>(subId),
    };
  }

  CoreConfigData copyWith({
    int? id,
    String? name,
    String? type,
    String? tags,
    Value<String?> data = const Value.absent(),
    int? delay,
    int? subId,
  }) => CoreConfigData(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    tags: tags ?? this.tags,
    data: data.present ? data.value : this.data,
    delay: delay ?? this.delay,
    subId: subId ?? this.subId,
  );
  CoreConfigData copyWithCompanion(CoreConfigCompanion data) {
    return CoreConfigData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      tags: data.tags.present ? data.tags.value : this.tags,
      data: data.data.present ? data.data.value : this.data,
      delay: data.delay.present ? data.delay.value : this.delay,
      subId: data.subId.present ? data.subId.value : this.subId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoreConfigData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('tags: $tags, ')
          ..write('data: $data, ')
          ..write('delay: $delay, ')
          ..write('subId: $subId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, tags, data, delay, subId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoreConfigData &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.tags == this.tags &&
          other.data == this.data &&
          other.delay == this.delay &&
          other.subId == this.subId);
}

class CoreConfigCompanion extends UpdateCompanion<CoreConfigData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> tags;
  final Value<String?> data;
  final Value<int> delay;
  final Value<int> subId;
  const CoreConfigCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.tags = const Value.absent(),
    this.data = const Value.absent(),
    this.delay = const Value.absent(),
    this.subId = const Value.absent(),
  });
  CoreConfigCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    required String tags,
    this.data = const Value.absent(),
    required int delay,
    required int subId,
  }) : name = Value(name),
       type = Value(type),
       tags = Value(tags),
       delay = Value(delay),
       subId = Value(subId);
  static Insertable<CoreConfigData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? tags,
    Expression<String>? data,
    Expression<int>? delay,
    Expression<int>? subId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (tags != null) 'tags': tags,
      if (data != null) 'data': data,
      if (delay != null) 'delay': delay,
      if (subId != null) 'sub_id': subId,
    });
  }

  CoreConfigCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? tags,
    Value<String?>? data,
    Value<int>? delay,
    Value<int>? subId,
  }) {
    return CoreConfigCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      data: data ?? this.data,
      delay: delay ?? this.delay,
      subId: subId ?? this.subId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (delay.present) {
      map['delay'] = Variable<int>(delay.value);
    }
    if (subId.present) {
      map['sub_id'] = Variable<int>(subId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoreConfigCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('tags: $tags, ')
          ..write('data: $data, ')
          ..write('delay: $delay, ')
          ..write('subId: $subId')
          ..write(')'))
        .toString();
  }
}

class $SubscriptionTable extends Subscription
    with TableInfo<$SubscriptionTable, SubscriptionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubscriptionTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expandedMeta = const VerificationMeta(
    'expanded',
  );
  @override
  late final GeneratedColumn<bool> expanded = GeneratedColumn<bool>(
    'expanded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("expanded" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    url,
    timestamp,
    count,
    expanded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subscription';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubscriptionData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('expanded')) {
      context.handle(
        _expandedMeta,
        expanded.isAcceptableOrUnknown(data['expanded']!, _expandedMeta),
      );
    } else if (isInserting) {
      context.missing(_expandedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubscriptionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubscriptionData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      expanded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}expanded'],
      )!,
    );
  }

  @override
  $SubscriptionTable createAlias(String alias) {
    return $SubscriptionTable(attachedDatabase, alias);
  }
}

class SubscriptionData extends DataClass
    implements Insertable<SubscriptionData> {
  final int id;
  final String name;
  final String url;
  final DateTime timestamp;
  final int count;
  final bool expanded;
  const SubscriptionData({
    required this.id,
    required this.name,
    required this.url,
    required this.timestamp,
    required this.count,
    required this.expanded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['count'] = Variable<int>(count);
    map['expanded'] = Variable<bool>(expanded);
    return map;
  }

  SubscriptionCompanion toCompanion(bool nullToAbsent) {
    return SubscriptionCompanion(
      id: Value(id),
      name: Value(name),
      url: Value(url),
      timestamp: Value(timestamp),
      count: Value(count),
      expanded: Value(expanded),
    );
  }

  factory SubscriptionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubscriptionData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      count: serializer.fromJson<int>(json['count']),
      expanded: serializer.fromJson<bool>(json['expanded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'count': serializer.toJson<int>(count),
      'expanded': serializer.toJson<bool>(expanded),
    };
  }

  SubscriptionData copyWith({
    int? id,
    String? name,
    String? url,
    DateTime? timestamp,
    int? count,
    bool? expanded,
  }) => SubscriptionData(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    timestamp: timestamp ?? this.timestamp,
    count: count ?? this.count,
    expanded: expanded ?? this.expanded,
  );
  SubscriptionData copyWithCompanion(SubscriptionCompanion data) {
    return SubscriptionData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      count: data.count.present ? data.count.value : this.count,
      expanded: data.expanded.present ? data.expanded.value : this.expanded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('timestamp: $timestamp, ')
          ..write('count: $count, ')
          ..write('expanded: $expanded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, url, timestamp, count, expanded);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubscriptionData &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.timestamp == this.timestamp &&
          other.count == this.count &&
          other.expanded == this.expanded);
}

class SubscriptionCompanion extends UpdateCompanion<SubscriptionData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> url;
  final Value<DateTime> timestamp;
  final Value<int> count;
  final Value<bool> expanded;
  const SubscriptionCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.count = const Value.absent(),
    this.expanded = const Value.absent(),
  });
  SubscriptionCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String url,
    required DateTime timestamp,
    required int count,
    required bool expanded,
  }) : name = Value(name),
       url = Value(url),
       timestamp = Value(timestamp),
       count = Value(count),
       expanded = Value(expanded);
  static Insertable<SubscriptionData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<DateTime>? timestamp,
    Expression<int>? count,
    Expression<bool>? expanded,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (timestamp != null) 'timestamp': timestamp,
      if (count != null) 'count': count,
      if (expanded != null) 'expanded': expanded,
    });
  }

  SubscriptionCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? url,
    Value<DateTime>? timestamp,
    Value<int>? count,
    Value<bool>? expanded,
  }) {
    return SubscriptionCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      timestamp: timestamp ?? this.timestamp,
      count: count ?? this.count,
      expanded: expanded ?? this.expanded,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (expanded.present) {
      map['expanded'] = Variable<bool>(expanded.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('timestamp: $timestamp, ')
          ..write('count: $count, ')
          ..write('expanded: $expanded')
          ..write(')'))
        .toString();
  }
}

class $GeoDataTable extends GeoData with TableInfo<$GeoDataTable, GeoDataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GeoDataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryCountMeta = const VerificationMeta(
    'categoryCount',
  );
  @override
  late final GeneratedColumn<int> categoryCount = GeneratedColumn<int>(
    'category_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleCountMeta = const VerificationMeta(
    'ruleCount',
  );
  @override
  late final GeneratedColumn<int> ruleCount = GeneratedColumn<int>(
    'rule_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    url,
    timestamp,
    categoryCount,
    ruleCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'geo_data';
  @override
  VerificationContext validateIntegrity(
    Insertable<GeoDataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('category_count')) {
      context.handle(
        _categoryCountMeta,
        categoryCount.isAcceptableOrUnknown(
          data['category_count']!,
          _categoryCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryCountMeta);
    }
    if (data.containsKey('rule_count')) {
      context.handle(
        _ruleCountMeta,
        ruleCount.isAcceptableOrUnknown(data['rule_count']!, _ruleCountMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GeoDataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GeoDataData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      categoryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_count'],
      )!,
      ruleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rule_count'],
      )!,
    );
  }

  @override
  $GeoDataTable createAlias(String alias) {
    return $GeoDataTable(attachedDatabase, alias);
  }
}

class GeoDataData extends DataClass implements Insertable<GeoDataData> {
  final int id;
  final String name;
  final String type;
  final String url;
  final DateTime timestamp;
  final int categoryCount;
  final int ruleCount;
  const GeoDataData({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.timestamp,
    required this.categoryCount,
    required this.ruleCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['url'] = Variable<String>(url);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['category_count'] = Variable<int>(categoryCount);
    map['rule_count'] = Variable<int>(ruleCount);
    return map;
  }

  GeoDataCompanion toCompanion(bool nullToAbsent) {
    return GeoDataCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      url: Value(url),
      timestamp: Value(timestamp),
      categoryCount: Value(categoryCount),
      ruleCount: Value(ruleCount),
    );
  }

  factory GeoDataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GeoDataData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      url: serializer.fromJson<String>(json['url']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      categoryCount: serializer.fromJson<int>(json['categoryCount']),
      ruleCount: serializer.fromJson<int>(json['ruleCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'url': serializer.toJson<String>(url),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'categoryCount': serializer.toJson<int>(categoryCount),
      'ruleCount': serializer.toJson<int>(ruleCount),
    };
  }

  GeoDataData copyWith({
    int? id,
    String? name,
    String? type,
    String? url,
    DateTime? timestamp,
    int? categoryCount,
    int? ruleCount,
  }) => GeoDataData(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    url: url ?? this.url,
    timestamp: timestamp ?? this.timestamp,
    categoryCount: categoryCount ?? this.categoryCount,
    ruleCount: ruleCount ?? this.ruleCount,
  );
  GeoDataData copyWithCompanion(GeoDataCompanion data) {
    return GeoDataData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      url: data.url.present ? data.url.value : this.url,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      categoryCount: data.categoryCount.present
          ? data.categoryCount.value
          : this.categoryCount,
      ruleCount: data.ruleCount.present ? data.ruleCount.value : this.ruleCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GeoDataData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('timestamp: $timestamp, ')
          ..write('categoryCount: $categoryCount, ')
          ..write('ruleCount: $ruleCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, url, timestamp, categoryCount, ruleCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeoDataData &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.url == this.url &&
          other.timestamp == this.timestamp &&
          other.categoryCount == this.categoryCount &&
          other.ruleCount == this.ruleCount);
}

class GeoDataCompanion extends UpdateCompanion<GeoDataData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> url;
  final Value<DateTime> timestamp;
  final Value<int> categoryCount;
  final Value<int> ruleCount;
  const GeoDataCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.url = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.categoryCount = const Value.absent(),
    this.ruleCount = const Value.absent(),
  });
  GeoDataCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    required String url,
    required DateTime timestamp,
    required int categoryCount,
    required int ruleCount,
  }) : name = Value(name),
       type = Value(type),
       url = Value(url),
       timestamp = Value(timestamp),
       categoryCount = Value(categoryCount),
       ruleCount = Value(ruleCount);
  static Insertable<GeoDataData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? url,
    Expression<DateTime>? timestamp,
    Expression<int>? categoryCount,
    Expression<int>? ruleCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (url != null) 'url': url,
      if (timestamp != null) 'timestamp': timestamp,
      if (categoryCount != null) 'category_count': categoryCount,
      if (ruleCount != null) 'rule_count': ruleCount,
    });
  }

  GeoDataCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? url,
    Value<DateTime>? timestamp,
    Value<int>? categoryCount,
    Value<int>? ruleCount,
  }) {
    return GeoDataCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      timestamp: timestamp ?? this.timestamp,
      categoryCount: categoryCount ?? this.categoryCount,
      ruleCount: ruleCount ?? this.ruleCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (categoryCount.present) {
      map['category_count'] = Variable<int>(categoryCount.value);
    }
    if (ruleCount.present) {
      map['rule_count'] = Variable<int>(ruleCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GeoDataCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('timestamp: $timestamp, ')
          ..write('categoryCount: $categoryCount, ')
          ..write('ruleCount: $ruleCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CoreConfigTable coreConfig = $CoreConfigTable(this);
  late final $SubscriptionTable subscription = $SubscriptionTable(this);
  late final $GeoDataTable geoData = $GeoDataTable(this);
  late final CoreConfigDao coreConfigDao = CoreConfigDao(this as AppDatabase);
  late final SubscriptionDao subscriptionDao = SubscriptionDao(
    this as AppDatabase,
  );
  late final GeoDataDao geoDataDao = GeoDataDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    coreConfig,
    subscription,
    geoData,
  ];
}

typedef $$CoreConfigTableCreateCompanionBuilder =
    CoreConfigCompanion Function({
      Value<int> id,
      required String name,
      required String type,
      required String tags,
      Value<String?> data,
      required int delay,
      required int subId,
    });
typedef $$CoreConfigTableUpdateCompanionBuilder =
    CoreConfigCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String> tags,
      Value<String?> data,
      Value<int> delay,
      Value<int> subId,
    });

class $$CoreConfigTableFilterComposer
    extends Composer<_$AppDatabase, $CoreConfigTable> {
  $$CoreConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delay => $composableBuilder(
    column: $table.delay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subId => $composableBuilder(
    column: $table.subId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoreConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $CoreConfigTable> {
  $$CoreConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delay => $composableBuilder(
    column: $table.delay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subId => $composableBuilder(
    column: $table.subId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoreConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoreConfigTable> {
  $$CoreConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get delay =>
      $composableBuilder(column: $table.delay, builder: (column) => column);

  GeneratedColumn<int> get subId =>
      $composableBuilder(column: $table.subId, builder: (column) => column);
}

class $$CoreConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoreConfigTable,
          CoreConfigData,
          $$CoreConfigTableFilterComposer,
          $$CoreConfigTableOrderingComposer,
          $$CoreConfigTableAnnotationComposer,
          $$CoreConfigTableCreateCompanionBuilder,
          $$CoreConfigTableUpdateCompanionBuilder,
          (
            CoreConfigData,
            BaseReferences<_$AppDatabase, $CoreConfigTable, CoreConfigData>,
          ),
          CoreConfigData,
          PrefetchHooks Function()
        > {
  $$CoreConfigTableTableManager(_$AppDatabase db, $CoreConfigTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoreConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoreConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoreConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> data = const Value.absent(),
                Value<int> delay = const Value.absent(),
                Value<int> subId = const Value.absent(),
              }) => CoreConfigCompanion(
                id: id,
                name: name,
                type: type,
                tags: tags,
                data: data,
                delay: delay,
                subId: subId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String type,
                required String tags,
                Value<String?> data = const Value.absent(),
                required int delay,
                required int subId,
              }) => CoreConfigCompanion.insert(
                id: id,
                name: name,
                type: type,
                tags: tags,
                data: data,
                delay: delay,
                subId: subId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoreConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoreConfigTable,
      CoreConfigData,
      $$CoreConfigTableFilterComposer,
      $$CoreConfigTableOrderingComposer,
      $$CoreConfigTableAnnotationComposer,
      $$CoreConfigTableCreateCompanionBuilder,
      $$CoreConfigTableUpdateCompanionBuilder,
      (
        CoreConfigData,
        BaseReferences<_$AppDatabase, $CoreConfigTable, CoreConfigData>,
      ),
      CoreConfigData,
      PrefetchHooks Function()
    >;
typedef $$SubscriptionTableCreateCompanionBuilder =
    SubscriptionCompanion Function({
      Value<int> id,
      required String name,
      required String url,
      required DateTime timestamp,
      required int count,
      required bool expanded,
    });
typedef $$SubscriptionTableUpdateCompanionBuilder =
    SubscriptionCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> url,
      Value<DateTime> timestamp,
      Value<int> count,
      Value<bool> expanded,
    });

class $$SubscriptionTableFilterComposer
    extends Composer<_$AppDatabase, $SubscriptionTable> {
  $$SubscriptionTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get expanded => $composableBuilder(
    column: $table.expanded,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubscriptionTableOrderingComposer
    extends Composer<_$AppDatabase, $SubscriptionTable> {
  $$SubscriptionTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get expanded => $composableBuilder(
    column: $table.expanded,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubscriptionTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubscriptionTable> {
  $$SubscriptionTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<bool> get expanded =>
      $composableBuilder(column: $table.expanded, builder: (column) => column);
}

class $$SubscriptionTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubscriptionTable,
          SubscriptionData,
          $$SubscriptionTableFilterComposer,
          $$SubscriptionTableOrderingComposer,
          $$SubscriptionTableAnnotationComposer,
          $$SubscriptionTableCreateCompanionBuilder,
          $$SubscriptionTableUpdateCompanionBuilder,
          (
            SubscriptionData,
            BaseReferences<_$AppDatabase, $SubscriptionTable, SubscriptionData>,
          ),
          SubscriptionData,
          PrefetchHooks Function()
        > {
  $$SubscriptionTableTableManager(_$AppDatabase db, $SubscriptionTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubscriptionTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubscriptionTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubscriptionTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<bool> expanded = const Value.absent(),
              }) => SubscriptionCompanion(
                id: id,
                name: name,
                url: url,
                timestamp: timestamp,
                count: count,
                expanded: expanded,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String url,
                required DateTime timestamp,
                required int count,
                required bool expanded,
              }) => SubscriptionCompanion.insert(
                id: id,
                name: name,
                url: url,
                timestamp: timestamp,
                count: count,
                expanded: expanded,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubscriptionTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubscriptionTable,
      SubscriptionData,
      $$SubscriptionTableFilterComposer,
      $$SubscriptionTableOrderingComposer,
      $$SubscriptionTableAnnotationComposer,
      $$SubscriptionTableCreateCompanionBuilder,
      $$SubscriptionTableUpdateCompanionBuilder,
      (
        SubscriptionData,
        BaseReferences<_$AppDatabase, $SubscriptionTable, SubscriptionData>,
      ),
      SubscriptionData,
      PrefetchHooks Function()
    >;
typedef $$GeoDataTableCreateCompanionBuilder =
    GeoDataCompanion Function({
      Value<int> id,
      required String name,
      required String type,
      required String url,
      required DateTime timestamp,
      required int categoryCount,
      required int ruleCount,
    });
typedef $$GeoDataTableUpdateCompanionBuilder =
    GeoDataCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String> url,
      Value<DateTime> timestamp,
      Value<int> categoryCount,
      Value<int> ruleCount,
    });

class $$GeoDataTableFilterComposer
    extends Composer<_$AppDatabase, $GeoDataTable> {
  $$GeoDataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryCount => $composableBuilder(
    column: $table.categoryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ruleCount => $composableBuilder(
    column: $table.ruleCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GeoDataTableOrderingComposer
    extends Composer<_$AppDatabase, $GeoDataTable> {
  $$GeoDataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryCount => $composableBuilder(
    column: $table.categoryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ruleCount => $composableBuilder(
    column: $table.ruleCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GeoDataTableAnnotationComposer
    extends Composer<_$AppDatabase, $GeoDataTable> {
  $$GeoDataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get categoryCount => $composableBuilder(
    column: $table.categoryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ruleCount =>
      $composableBuilder(column: $table.ruleCount, builder: (column) => column);
}

class $$GeoDataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GeoDataTable,
          GeoDataData,
          $$GeoDataTableFilterComposer,
          $$GeoDataTableOrderingComposer,
          $$GeoDataTableAnnotationComposer,
          $$GeoDataTableCreateCompanionBuilder,
          $$GeoDataTableUpdateCompanionBuilder,
          (
            GeoDataData,
            BaseReferences<_$AppDatabase, $GeoDataTable, GeoDataData>,
          ),
          GeoDataData,
          PrefetchHooks Function()
        > {
  $$GeoDataTableTableManager(_$AppDatabase db, $GeoDataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GeoDataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GeoDataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GeoDataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> categoryCount = const Value.absent(),
                Value<int> ruleCount = const Value.absent(),
              }) => GeoDataCompanion(
                id: id,
                name: name,
                type: type,
                url: url,
                timestamp: timestamp,
                categoryCount: categoryCount,
                ruleCount: ruleCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String type,
                required String url,
                required DateTime timestamp,
                required int categoryCount,
                required int ruleCount,
              }) => GeoDataCompanion.insert(
                id: id,
                name: name,
                type: type,
                url: url,
                timestamp: timestamp,
                categoryCount: categoryCount,
                ruleCount: ruleCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GeoDataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GeoDataTable,
      GeoDataData,
      $$GeoDataTableFilterComposer,
      $$GeoDataTableOrderingComposer,
      $$GeoDataTableAnnotationComposer,
      $$GeoDataTableCreateCompanionBuilder,
      $$GeoDataTableUpdateCompanionBuilder,
      (GeoDataData, BaseReferences<_$AppDatabase, $GeoDataTable, GeoDataData>),
      GeoDataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CoreConfigTableTableManager get coreConfig =>
      $$CoreConfigTableTableManager(_db, _db.coreConfig);
  $$SubscriptionTableTableManager get subscription =>
      $$SubscriptionTableTableManager(_db, _db.subscription);
  $$GeoDataTableTableManager get geoData =>
      $$GeoDataTableTableManager(_db, _db.geoData);
}
