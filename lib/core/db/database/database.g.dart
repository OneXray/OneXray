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
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationSourceMeta = const VerificationMeta(
    'locationSource',
  );
  @override
  late final GeneratedColumn<String> locationSource = GeneratedColumn<String>(
    'location_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMeasuredAtMeta = const VerificationMeta(
    'lastMeasuredAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMeasuredAt =
      GeneratedColumn<DateTime>(
        'last_measured_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    countryCode,
    locationSource,
    lastMeasuredAt,
    favorite,
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
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    }
    if (data.containsKey('location_source')) {
      context.handle(
        _locationSourceMeta,
        locationSource.isAcceptableOrUnknown(
          data['location_source']!,
          _locationSourceMeta,
        ),
      );
    }
    if (data.containsKey('last_measured_at')) {
      context.handle(
        _lastMeasuredAtMeta,
        lastMeasuredAt.isAcceptableOrUnknown(
          data['last_measured_at']!,
          _lastMeasuredAtMeta,
        ),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
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
      countryCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country_code'],
      ),
      locationSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_source'],
      ),
      lastMeasuredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_measured_at'],
      ),
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
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
  final String? countryCode;
  final String? locationSource;
  final DateTime? lastMeasuredAt;
  final bool favorite;
  const CoreConfigData({
    required this.id,
    required this.name,
    required this.type,
    required this.tags,
    this.data,
    required this.delay,
    required this.subId,
    this.countryCode,
    this.locationSource,
    this.lastMeasuredAt,
    required this.favorite,
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
    if (!nullToAbsent || countryCode != null) {
      map['country_code'] = Variable<String>(countryCode);
    }
    if (!nullToAbsent || locationSource != null) {
      map['location_source'] = Variable<String>(locationSource);
    }
    if (!nullToAbsent || lastMeasuredAt != null) {
      map['last_measured_at'] = Variable<DateTime>(lastMeasuredAt);
    }
    map['favorite'] = Variable<bool>(favorite);
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
      countryCode: countryCode == null && nullToAbsent
          ? const Value.absent()
          : Value(countryCode),
      locationSource: locationSource == null && nullToAbsent
          ? const Value.absent()
          : Value(locationSource),
      lastMeasuredAt: lastMeasuredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMeasuredAt),
      favorite: Value(favorite),
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
      countryCode: serializer.fromJson<String?>(json['countryCode']),
      locationSource: serializer.fromJson<String?>(json['locationSource']),
      lastMeasuredAt: serializer.fromJson<DateTime?>(json['lastMeasuredAt']),
      favorite: serializer.fromJson<bool>(json['favorite']),
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
      'countryCode': serializer.toJson<String?>(countryCode),
      'locationSource': serializer.toJson<String?>(locationSource),
      'lastMeasuredAt': serializer.toJson<DateTime?>(lastMeasuredAt),
      'favorite': serializer.toJson<bool>(favorite),
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
    Value<String?> countryCode = const Value.absent(),
    Value<String?> locationSource = const Value.absent(),
    Value<DateTime?> lastMeasuredAt = const Value.absent(),
    bool? favorite,
  }) => CoreConfigData(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    tags: tags ?? this.tags,
    data: data.present ? data.value : this.data,
    delay: delay ?? this.delay,
    subId: subId ?? this.subId,
    countryCode: countryCode.present ? countryCode.value : this.countryCode,
    locationSource: locationSource.present
        ? locationSource.value
        : this.locationSource,
    lastMeasuredAt: lastMeasuredAt.present
        ? lastMeasuredAt.value
        : this.lastMeasuredAt,
    favorite: favorite ?? this.favorite,
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
      countryCode: data.countryCode.present
          ? data.countryCode.value
          : this.countryCode,
      locationSource: data.locationSource.present
          ? data.locationSource.value
          : this.locationSource,
      lastMeasuredAt: data.lastMeasuredAt.present
          ? data.lastMeasuredAt.value
          : this.lastMeasuredAt,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
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
          ..write('subId: $subId, ')
          ..write('countryCode: $countryCode, ')
          ..write('locationSource: $locationSource, ')
          ..write('lastMeasuredAt: $lastMeasuredAt, ')
          ..write('favorite: $favorite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    tags,
    data,
    delay,
    subId,
    countryCode,
    locationSource,
    lastMeasuredAt,
    favorite,
  );
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
          other.subId == this.subId &&
          other.countryCode == this.countryCode &&
          other.locationSource == this.locationSource &&
          other.lastMeasuredAt == this.lastMeasuredAt &&
          other.favorite == this.favorite);
}

class CoreConfigCompanion extends UpdateCompanion<CoreConfigData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> tags;
  final Value<String?> data;
  final Value<int> delay;
  final Value<int> subId;
  final Value<String?> countryCode;
  final Value<String?> locationSource;
  final Value<DateTime?> lastMeasuredAt;
  final Value<bool> favorite;
  const CoreConfigCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.tags = const Value.absent(),
    this.data = const Value.absent(),
    this.delay = const Value.absent(),
    this.subId = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.locationSource = const Value.absent(),
    this.lastMeasuredAt = const Value.absent(),
    this.favorite = const Value.absent(),
  });
  CoreConfigCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    required String tags,
    this.data = const Value.absent(),
    required int delay,
    required int subId,
    this.countryCode = const Value.absent(),
    this.locationSource = const Value.absent(),
    this.lastMeasuredAt = const Value.absent(),
    this.favorite = const Value.absent(),
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
    Expression<String>? countryCode,
    Expression<String>? locationSource,
    Expression<DateTime>? lastMeasuredAt,
    Expression<bool>? favorite,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (tags != null) 'tags': tags,
      if (data != null) 'data': data,
      if (delay != null) 'delay': delay,
      if (subId != null) 'sub_id': subId,
      if (countryCode != null) 'country_code': countryCode,
      if (locationSource != null) 'location_source': locationSource,
      if (lastMeasuredAt != null) 'last_measured_at': lastMeasuredAt,
      if (favorite != null) 'favorite': favorite,
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
    Value<String?>? countryCode,
    Value<String?>? locationSource,
    Value<DateTime?>? lastMeasuredAt,
    Value<bool>? favorite,
  }) {
    return CoreConfigCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      data: data ?? this.data,
      delay: delay ?? this.delay,
      subId: subId ?? this.subId,
      countryCode: countryCode ?? this.countryCode,
      locationSource: locationSource ?? this.locationSource,
      lastMeasuredAt: lastMeasuredAt ?? this.lastMeasuredAt,
      favorite: favorite ?? this.favorite,
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
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (locationSource.present) {
      map['location_source'] = Variable<String>(locationSource.value);
    }
    if (lastMeasuredAt.present) {
      map['last_measured_at'] = Variable<DateTime>(lastMeasuredAt.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
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
          ..write('subId: $subId, ')
          ..write('countryCode: $countryCode, ')
          ..write('locationSource: $locationSource, ')
          ..write('lastMeasuredAt: $lastMeasuredAt, ')
          ..write('favorite: $favorite')
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
  static const VerificationMeta _ageSecretKeyMeta = const VerificationMeta(
    'ageSecretKey',
  );
  @override
  late final GeneratedColumn<String> ageSecretKey = GeneratedColumn<String>(
    'age_secret_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _agePublicKeyMeta = const VerificationMeta(
    'agePublicKey',
  );
  @override
  late final GeneratedColumn<String> agePublicKey = GeneratedColumn<String>(
    'age_public_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _parseFailureCountMeta = const VerificationMeta(
    'parseFailureCount',
  );
  @override
  late final GeneratedColumn<int> parseFailureCount = GeneratedColumn<int>(
    'parse_failure_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _autoUpdateMeta = const VerificationMeta(
    'autoUpdate',
  );
  @override
  late final GeneratedColumn<bool> autoUpdate = GeneratedColumn<bool>(
    'auto_update',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_update" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    url,
    ageSecretKey,
    agePublicKey,
    timestamp,
    count,
    expanded,
    parseFailureCount,
    autoUpdate,
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
    if (data.containsKey('age_secret_key')) {
      context.handle(
        _ageSecretKeyMeta,
        ageSecretKey.isAcceptableOrUnknown(
          data['age_secret_key']!,
          _ageSecretKeyMeta,
        ),
      );
    }
    if (data.containsKey('age_public_key')) {
      context.handle(
        _agePublicKeyMeta,
        agePublicKey.isAcceptableOrUnknown(
          data['age_public_key']!,
          _agePublicKeyMeta,
        ),
      );
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
    if (data.containsKey('parse_failure_count')) {
      context.handle(
        _parseFailureCountMeta,
        parseFailureCount.isAcceptableOrUnknown(
          data['parse_failure_count']!,
          _parseFailureCountMeta,
        ),
      );
    }
    if (data.containsKey('auto_update')) {
      context.handle(
        _autoUpdateMeta,
        autoUpdate.isAcceptableOrUnknown(data['auto_update']!, _autoUpdateMeta),
      );
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
      ageSecretKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_secret_key'],
      ),
      agePublicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_public_key'],
      ),
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
      parseFailureCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parse_failure_count'],
      )!,
      autoUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_update'],
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
  final String? ageSecretKey;
  final String? agePublicKey;
  final DateTime timestamp;
  final int count;
  final bool expanded;
  final int parseFailureCount;
  final bool autoUpdate;
  const SubscriptionData({
    required this.id,
    required this.name,
    required this.url,
    this.ageSecretKey,
    this.agePublicKey,
    required this.timestamp,
    required this.count,
    required this.expanded,
    required this.parseFailureCount,
    required this.autoUpdate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || ageSecretKey != null) {
      map['age_secret_key'] = Variable<String>(ageSecretKey);
    }
    if (!nullToAbsent || agePublicKey != null) {
      map['age_public_key'] = Variable<String>(agePublicKey);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['count'] = Variable<int>(count);
    map['expanded'] = Variable<bool>(expanded);
    map['parse_failure_count'] = Variable<int>(parseFailureCount);
    map['auto_update'] = Variable<bool>(autoUpdate);
    return map;
  }

  SubscriptionCompanion toCompanion(bool nullToAbsent) {
    return SubscriptionCompanion(
      id: Value(id),
      name: Value(name),
      url: Value(url),
      ageSecretKey: ageSecretKey == null && nullToAbsent
          ? const Value.absent()
          : Value(ageSecretKey),
      agePublicKey: agePublicKey == null && nullToAbsent
          ? const Value.absent()
          : Value(agePublicKey),
      timestamp: Value(timestamp),
      count: Value(count),
      expanded: Value(expanded),
      parseFailureCount: Value(parseFailureCount),
      autoUpdate: Value(autoUpdate),
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
      ageSecretKey: serializer.fromJson<String?>(json['ageSecretKey']),
      agePublicKey: serializer.fromJson<String?>(json['agePublicKey']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      count: serializer.fromJson<int>(json['count']),
      expanded: serializer.fromJson<bool>(json['expanded']),
      parseFailureCount: serializer.fromJson<int>(json['parseFailureCount']),
      autoUpdate: serializer.fromJson<bool>(json['autoUpdate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'ageSecretKey': serializer.toJson<String?>(ageSecretKey),
      'agePublicKey': serializer.toJson<String?>(agePublicKey),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'count': serializer.toJson<int>(count),
      'expanded': serializer.toJson<bool>(expanded),
      'parseFailureCount': serializer.toJson<int>(parseFailureCount),
      'autoUpdate': serializer.toJson<bool>(autoUpdate),
    };
  }

  SubscriptionData copyWith({
    int? id,
    String? name,
    String? url,
    Value<String?> ageSecretKey = const Value.absent(),
    Value<String?> agePublicKey = const Value.absent(),
    DateTime? timestamp,
    int? count,
    bool? expanded,
    int? parseFailureCount,
    bool? autoUpdate,
  }) => SubscriptionData(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    ageSecretKey: ageSecretKey.present ? ageSecretKey.value : this.ageSecretKey,
    agePublicKey: agePublicKey.present ? agePublicKey.value : this.agePublicKey,
    timestamp: timestamp ?? this.timestamp,
    count: count ?? this.count,
    expanded: expanded ?? this.expanded,
    parseFailureCount: parseFailureCount ?? this.parseFailureCount,
    autoUpdate: autoUpdate ?? this.autoUpdate,
  );
  SubscriptionData copyWithCompanion(SubscriptionCompanion data) {
    return SubscriptionData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      ageSecretKey: data.ageSecretKey.present
          ? data.ageSecretKey.value
          : this.ageSecretKey,
      agePublicKey: data.agePublicKey.present
          ? data.agePublicKey.value
          : this.agePublicKey,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      count: data.count.present ? data.count.value : this.count,
      expanded: data.expanded.present ? data.expanded.value : this.expanded,
      parseFailureCount: data.parseFailureCount.present
          ? data.parseFailureCount.value
          : this.parseFailureCount,
      autoUpdate: data.autoUpdate.present
          ? data.autoUpdate.value
          : this.autoUpdate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('ageSecretKey: $ageSecretKey, ')
          ..write('agePublicKey: $agePublicKey, ')
          ..write('timestamp: $timestamp, ')
          ..write('count: $count, ')
          ..write('expanded: $expanded, ')
          ..write('parseFailureCount: $parseFailureCount, ')
          ..write('autoUpdate: $autoUpdate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    url,
    ageSecretKey,
    agePublicKey,
    timestamp,
    count,
    expanded,
    parseFailureCount,
    autoUpdate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubscriptionData &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.ageSecretKey == this.ageSecretKey &&
          other.agePublicKey == this.agePublicKey &&
          other.timestamp == this.timestamp &&
          other.count == this.count &&
          other.expanded == this.expanded &&
          other.parseFailureCount == this.parseFailureCount &&
          other.autoUpdate == this.autoUpdate);
}

class SubscriptionCompanion extends UpdateCompanion<SubscriptionData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> url;
  final Value<String?> ageSecretKey;
  final Value<String?> agePublicKey;
  final Value<DateTime> timestamp;
  final Value<int> count;
  final Value<bool> expanded;
  final Value<int> parseFailureCount;
  final Value<bool> autoUpdate;
  const SubscriptionCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.ageSecretKey = const Value.absent(),
    this.agePublicKey = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.count = const Value.absent(),
    this.expanded = const Value.absent(),
    this.parseFailureCount = const Value.absent(),
    this.autoUpdate = const Value.absent(),
  });
  SubscriptionCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String url,
    this.ageSecretKey = const Value.absent(),
    this.agePublicKey = const Value.absent(),
    required DateTime timestamp,
    required int count,
    required bool expanded,
    this.parseFailureCount = const Value.absent(),
    this.autoUpdate = const Value.absent(),
  }) : name = Value(name),
       url = Value(url),
       timestamp = Value(timestamp),
       count = Value(count),
       expanded = Value(expanded);
  static Insertable<SubscriptionData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? ageSecretKey,
    Expression<String>? agePublicKey,
    Expression<DateTime>? timestamp,
    Expression<int>? count,
    Expression<bool>? expanded,
    Expression<int>? parseFailureCount,
    Expression<bool>? autoUpdate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (ageSecretKey != null) 'age_secret_key': ageSecretKey,
      if (agePublicKey != null) 'age_public_key': agePublicKey,
      if (timestamp != null) 'timestamp': timestamp,
      if (count != null) 'count': count,
      if (expanded != null) 'expanded': expanded,
      if (parseFailureCount != null) 'parse_failure_count': parseFailureCount,
      if (autoUpdate != null) 'auto_update': autoUpdate,
    });
  }

  SubscriptionCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? url,
    Value<String?>? ageSecretKey,
    Value<String?>? agePublicKey,
    Value<DateTime>? timestamp,
    Value<int>? count,
    Value<bool>? expanded,
    Value<int>? parseFailureCount,
    Value<bool>? autoUpdate,
  }) {
    return SubscriptionCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      ageSecretKey: ageSecretKey ?? this.ageSecretKey,
      agePublicKey: agePublicKey ?? this.agePublicKey,
      timestamp: timestamp ?? this.timestamp,
      count: count ?? this.count,
      expanded: expanded ?? this.expanded,
      parseFailureCount: parseFailureCount ?? this.parseFailureCount,
      autoUpdate: autoUpdate ?? this.autoUpdate,
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
    if (ageSecretKey.present) {
      map['age_secret_key'] = Variable<String>(ageSecretKey.value);
    }
    if (agePublicKey.present) {
      map['age_public_key'] = Variable<String>(agePublicKey.value);
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
    if (parseFailureCount.present) {
      map['parse_failure_count'] = Variable<int>(parseFailureCount.value);
    }
    if (autoUpdate.present) {
      map['auto_update'] = Variable<bool>(autoUpdate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('ageSecretKey: $ageSecretKey, ')
          ..write('agePublicKey: $agePublicKey, ')
          ..write('timestamp: $timestamp, ')
          ..write('count: $count, ')
          ..write('expanded: $expanded, ')
          ..write('parseFailureCount: $parseFailureCount, ')
          ..write('autoUpdate: $autoUpdate')
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

class $CustomRoutingProfilesTable extends CustomRoutingProfiles
    with TableInfo<$CustomRoutingProfilesTable, CustomRoutingProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomRoutingProfilesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_routing_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomRoutingProfileData> instance, {
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
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomRoutingProfileData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomRoutingProfileData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $CustomRoutingProfilesTable createAlias(String alias) {
    return $CustomRoutingProfilesTable(attachedDatabase, alias);
  }
}

class CustomRoutingProfileData extends DataClass
    implements Insertable<CustomRoutingProfileData> {
  final int id;
  final String name;
  final String data;
  const CustomRoutingProfileData({
    required this.id,
    required this.name,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['data'] = Variable<String>(data);
    return map;
  }

  CustomRoutingProfilesCompanion toCompanion(bool nullToAbsent) {
    return CustomRoutingProfilesCompanion(
      id: Value(id),
      name: Value(name),
      data: Value(data),
    );
  }

  factory CustomRoutingProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomRoutingProfileData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'data': serializer.toJson<String>(data),
    };
  }

  CustomRoutingProfileData copyWith({int? id, String? name, String? data}) =>
      CustomRoutingProfileData(
        id: id ?? this.id,
        name: name ?? this.name,
        data: data ?? this.data,
      );
  CustomRoutingProfileData copyWithCompanion(
    CustomRoutingProfilesCompanion data,
  ) {
    return CustomRoutingProfileData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomRoutingProfileData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomRoutingProfileData &&
          other.id == this.id &&
          other.name == this.name &&
          other.data == this.data);
}

class CustomRoutingProfilesCompanion
    extends UpdateCompanion<CustomRoutingProfileData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> data;
  const CustomRoutingProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.data = const Value.absent(),
  });
  CustomRoutingProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String data,
  }) : name = Value(name),
       data = Value(data);
  static Insertable<CustomRoutingProfileData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? data,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (data != null) 'data': data,
    });
  }

  CustomRoutingProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? data,
  }) {
    return CustomRoutingProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      data: data ?? this.data,
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
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomRoutingProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }
}

class $ConnectionStateTable extends ConnectionState
    with TableInfo<$ConnectionStateTable, ConnectionStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectionStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta(
    'settingsJson',
  );
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _confirmedSnapshotJsonMeta =
      const VerificationMeta('confirmedSnapshotJson');
  @override
  late final GeneratedColumn<String> confirmedSnapshotJson =
      GeneratedColumn<String>(
        'confirmed_snapshot_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pendingApplyJsonMeta = const VerificationMeta(
    'pendingApplyJson',
  );
  @override
  late final GeneratedColumn<String> pendingApplyJson = GeneratedColumn<String>(
    'pending_apply_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    revision,
    settingsJson,
    confirmedSnapshotJson,
    pendingApplyJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connection_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConnectionStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(
          data['settings_json']!,
          _settingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('confirmed_snapshot_json')) {
      context.handle(
        _confirmedSnapshotJsonMeta,
        confirmedSnapshotJson.isAcceptableOrUnknown(
          data['confirmed_snapshot_json']!,
          _confirmedSnapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('pending_apply_json')) {
      context.handle(
        _pendingApplyJsonMeta,
        pendingApplyJson.isAcceptableOrUnknown(
          data['pending_apply_json']!,
          _pendingApplyJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnectionStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectionStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
      )!,
      confirmedSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmed_snapshot_json'],
      ),
      pendingApplyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_apply_json'],
      ),
    );
  }

  @override
  $ConnectionStateTable createAlias(String alias) {
    return $ConnectionStateTable(attachedDatabase, alias);
  }
}

class ConnectionStateData extends DataClass
    implements Insertable<ConnectionStateData> {
  final int id;
  final int revision;
  final String settingsJson;
  final String? confirmedSnapshotJson;
  final String? pendingApplyJson;
  const ConnectionStateData({
    required this.id,
    required this.revision,
    required this.settingsJson,
    this.confirmedSnapshotJson,
    this.pendingApplyJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['revision'] = Variable<int>(revision);
    map['settings_json'] = Variable<String>(settingsJson);
    if (!nullToAbsent || confirmedSnapshotJson != null) {
      map['confirmed_snapshot_json'] = Variable<String>(confirmedSnapshotJson);
    }
    if (!nullToAbsent || pendingApplyJson != null) {
      map['pending_apply_json'] = Variable<String>(pendingApplyJson);
    }
    return map;
  }

  ConnectionStateCompanion toCompanion(bool nullToAbsent) {
    return ConnectionStateCompanion(
      id: Value(id),
      revision: Value(revision),
      settingsJson: Value(settingsJson),
      confirmedSnapshotJson: confirmedSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedSnapshotJson),
      pendingApplyJson: pendingApplyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingApplyJson),
    );
  }

  factory ConnectionStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectionStateData(
      id: serializer.fromJson<int>(json['id']),
      revision: serializer.fromJson<int>(json['revision']),
      settingsJson: serializer.fromJson<String>(json['settingsJson']),
      confirmedSnapshotJson: serializer.fromJson<String?>(
        json['confirmedSnapshotJson'],
      ),
      pendingApplyJson: serializer.fromJson<String?>(json['pendingApplyJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'revision': serializer.toJson<int>(revision),
      'settingsJson': serializer.toJson<String>(settingsJson),
      'confirmedSnapshotJson': serializer.toJson<String?>(
        confirmedSnapshotJson,
      ),
      'pendingApplyJson': serializer.toJson<String?>(pendingApplyJson),
    };
  }

  ConnectionStateData copyWith({
    int? id,
    int? revision,
    String? settingsJson,
    Value<String?> confirmedSnapshotJson = const Value.absent(),
    Value<String?> pendingApplyJson = const Value.absent(),
  }) => ConnectionStateData(
    id: id ?? this.id,
    revision: revision ?? this.revision,
    settingsJson: settingsJson ?? this.settingsJson,
    confirmedSnapshotJson: confirmedSnapshotJson.present
        ? confirmedSnapshotJson.value
        : this.confirmedSnapshotJson,
    pendingApplyJson: pendingApplyJson.present
        ? pendingApplyJson.value
        : this.pendingApplyJson,
  );
  ConnectionStateData copyWithCompanion(ConnectionStateCompanion data) {
    return ConnectionStateData(
      id: data.id.present ? data.id.value : this.id,
      revision: data.revision.present ? data.revision.value : this.revision,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
      confirmedSnapshotJson: data.confirmedSnapshotJson.present
          ? data.confirmedSnapshotJson.value
          : this.confirmedSnapshotJson,
      pendingApplyJson: data.pendingApplyJson.present
          ? data.pendingApplyJson.value
          : this.pendingApplyJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionStateData(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('confirmedSnapshotJson: $confirmedSnapshotJson, ')
          ..write('pendingApplyJson: $pendingApplyJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    revision,
    settingsJson,
    confirmedSnapshotJson,
    pendingApplyJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionStateData &&
          other.id == this.id &&
          other.revision == this.revision &&
          other.settingsJson == this.settingsJson &&
          other.confirmedSnapshotJson == this.confirmedSnapshotJson &&
          other.pendingApplyJson == this.pendingApplyJson);
}

class ConnectionStateCompanion extends UpdateCompanion<ConnectionStateData> {
  final Value<int> id;
  final Value<int> revision;
  final Value<String> settingsJson;
  final Value<String?> confirmedSnapshotJson;
  final Value<String?> pendingApplyJson;
  const ConnectionStateCompanion({
    this.id = const Value.absent(),
    this.revision = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.confirmedSnapshotJson = const Value.absent(),
    this.pendingApplyJson = const Value.absent(),
  });
  ConnectionStateCompanion.insert({
    this.id = const Value.absent(),
    this.revision = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.confirmedSnapshotJson = const Value.absent(),
    this.pendingApplyJson = const Value.absent(),
  });
  static Insertable<ConnectionStateData> custom({
    Expression<int>? id,
    Expression<int>? revision,
    Expression<String>? settingsJson,
    Expression<String>? confirmedSnapshotJson,
    Expression<String>? pendingApplyJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (revision != null) 'revision': revision,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (confirmedSnapshotJson != null)
        'confirmed_snapshot_json': confirmedSnapshotJson,
      if (pendingApplyJson != null) 'pending_apply_json': pendingApplyJson,
    });
  }

  ConnectionStateCompanion copyWith({
    Value<int>? id,
    Value<int>? revision,
    Value<String>? settingsJson,
    Value<String?>? confirmedSnapshotJson,
    Value<String?>? pendingApplyJson,
  }) {
    return ConnectionStateCompanion(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      settingsJson: settingsJson ?? this.settingsJson,
      confirmedSnapshotJson:
          confirmedSnapshotJson ?? this.confirmedSnapshotJson,
      pendingApplyJson: pendingApplyJson ?? this.pendingApplyJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (confirmedSnapshotJson.present) {
      map['confirmed_snapshot_json'] = Variable<String>(
        confirmedSnapshotJson.value,
      );
    }
    if (pendingApplyJson.present) {
      map['pending_apply_json'] = Variable<String>(pendingApplyJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionStateCompanion(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('confirmedSnapshotJson: $confirmedSnapshotJson, ')
          ..write('pendingApplyJson: $pendingApplyJson')
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
  late final $CustomRoutingProfilesTable customRoutingProfiles =
      $CustomRoutingProfilesTable(this);
  late final $ConnectionStateTable connectionState = $ConnectionStateTable(
    this,
  );
  late final CoreConfigDao coreConfigDao = CoreConfigDao(this as AppDatabase);
  late final SubscriptionDao subscriptionDao = SubscriptionDao(
    this as AppDatabase,
  );
  late final GeoDataDao geoDataDao = GeoDataDao(this as AppDatabase);
  late final CustomRoutingProfilesDao customRoutingProfilesDao =
      CustomRoutingProfilesDao(this as AppDatabase);
  late final ConnectionStateDao connectionStateDao = ConnectionStateDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    coreConfig,
    subscription,
    geoData,
    customRoutingProfiles,
    connectionState,
  ];
}

typedef $$CoreConfigTableCreateCompanionBuilder = CoreConfigCompanion Function({
  Value<int> id,
  required String name,
  required String type,
  required String tags,
  Value<String?> data,
  required int delay,
  required int subId,
  Value<String?> countryCode,
  Value<String?> locationSource,
  Value<DateTime?> lastMeasuredAt,
  Value<bool> favorite,
});
typedef $$CoreConfigTableUpdateCompanionBuilder = CoreConfigCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> type,
  Value<String> tags,
  Value<String?> data,
  Value<int> delay,
  Value<int> subId,
  Value<String?> countryCode,
  Value<String?> locationSource,
  Value<DateTime?> lastMeasuredAt,
  Value<bool> favorite,
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

  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationSource => $composableBuilder(
    column: $table.locationSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMeasuredAt => $composableBuilder(
    column: $table.lastMeasuredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
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

  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationSource => $composableBuilder(
    column: $table.locationSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMeasuredAt => $composableBuilder(
    column: $table.lastMeasuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
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

  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationSource => $composableBuilder(
    column: $table.locationSource,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastMeasuredAt => $composableBuilder(
    column: $table.lastMeasuredAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);
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
                Value<String?> countryCode = const Value.absent(),
                Value<String?> locationSource = const Value.absent(),
                Value<DateTime?> lastMeasuredAt = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
              }) => CoreConfigCompanion(
                id: id,
                name: name,
                type: type,
                tags: tags,
                data: data,
                delay: delay,
                subId: subId,
                countryCode: countryCode,
                locationSource: locationSource,
                lastMeasuredAt: lastMeasuredAt,
                favorite: favorite,
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
                Value<String?> countryCode = const Value.absent(),
                Value<String?> locationSource = const Value.absent(),
                Value<DateTime?> lastMeasuredAt = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
              }) => CoreConfigCompanion.insert(
                id: id,
                name: name,
                type: type,
                tags: tags,
                data: data,
                delay: delay,
                subId: subId,
                countryCode: countryCode,
                locationSource: locationSource,
                lastMeasuredAt: lastMeasuredAt,
                favorite: favorite,
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
      Value<String?> ageSecretKey,
      Value<String?> agePublicKey,
      required DateTime timestamp,
      required int count,
      required bool expanded,
      Value<int> parseFailureCount,
      Value<bool> autoUpdate,
    });
typedef $$SubscriptionTableUpdateCompanionBuilder =
    SubscriptionCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> url,
      Value<String?> ageSecretKey,
      Value<String?> agePublicKey,
      Value<DateTime> timestamp,
      Value<int> count,
      Value<bool> expanded,
      Value<int> parseFailureCount,
      Value<bool> autoUpdate,
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

  ColumnFilters<String> get ageSecretKey => $composableBuilder(
    column: $table.ageSecretKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agePublicKey => $composableBuilder(
    column: $table.agePublicKey,
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

  ColumnFilters<int> get parseFailureCount => $composableBuilder(
    column: $table.parseFailureCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
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

  ColumnOrderings<String> get ageSecretKey => $composableBuilder(
    column: $table.ageSecretKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agePublicKey => $composableBuilder(
    column: $table.agePublicKey,
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

  ColumnOrderings<int> get parseFailureCount => $composableBuilder(
    column: $table.parseFailureCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
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

  GeneratedColumn<String> get ageSecretKey => $composableBuilder(
    column: $table.ageSecretKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agePublicKey => $composableBuilder(
    column: $table.agePublicKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<bool> get expanded =>
      $composableBuilder(column: $table.expanded, builder: (column) => column);

  GeneratedColumn<int> get parseFailureCount => $composableBuilder(
    column: $table.parseFailureCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => column,
  );
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
                Value<String?> ageSecretKey = const Value.absent(),
                Value<String?> agePublicKey = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<bool> expanded = const Value.absent(),
                Value<int> parseFailureCount = const Value.absent(),
                Value<bool> autoUpdate = const Value.absent(),
              }) => SubscriptionCompanion(
                id: id,
                name: name,
                url: url,
                ageSecretKey: ageSecretKey,
                agePublicKey: agePublicKey,
                timestamp: timestamp,
                count: count,
                expanded: expanded,
                parseFailureCount: parseFailureCount,
                autoUpdate: autoUpdate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String url,
                Value<String?> ageSecretKey = const Value.absent(),
                Value<String?> agePublicKey = const Value.absent(),
                required DateTime timestamp,
                required int count,
                required bool expanded,
                Value<int> parseFailureCount = const Value.absent(),
                Value<bool> autoUpdate = const Value.absent(),
              }) => SubscriptionCompanion.insert(
                id: id,
                name: name,
                url: url,
                ageSecretKey: ageSecretKey,
                agePublicKey: agePublicKey,
                timestamp: timestamp,
                count: count,
                expanded: expanded,
                parseFailureCount: parseFailureCount,
                autoUpdate: autoUpdate,
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
typedef $$GeoDataTableCreateCompanionBuilder = GeoDataCompanion Function({
  Value<int> id,
  required String name,
  required String type,
  required String url,
  required DateTime timestamp,
  required int categoryCount,
  required int ruleCount,
});
typedef $$GeoDataTableUpdateCompanionBuilder = GeoDataCompanion Function({
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
typedef $$CustomRoutingProfilesTableCreateCompanionBuilder =
    CustomRoutingProfilesCompanion Function({
      Value<int> id,
      required String name,
      required String data,
    });
typedef $$CustomRoutingProfilesTableUpdateCompanionBuilder =
    CustomRoutingProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> data,
    });

class $$CustomRoutingProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomRoutingProfilesTable> {
  $$CustomRoutingProfilesTableFilterComposer({
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

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomRoutingProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomRoutingProfilesTable> {
  $$CustomRoutingProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomRoutingProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomRoutingProfilesTable> {
  $$CustomRoutingProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$CustomRoutingProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomRoutingProfilesTable,
          CustomRoutingProfileData,
          $$CustomRoutingProfilesTableFilterComposer,
          $$CustomRoutingProfilesTableOrderingComposer,
          $$CustomRoutingProfilesTableAnnotationComposer,
          $$CustomRoutingProfilesTableCreateCompanionBuilder,
          $$CustomRoutingProfilesTableUpdateCompanionBuilder,
          (
            CustomRoutingProfileData,
            BaseReferences<
              _$AppDatabase,
              $CustomRoutingProfilesTable,
              CustomRoutingProfileData
            >,
          ),
          CustomRoutingProfileData,
          PrefetchHooks Function()
        > {
  $$CustomRoutingProfilesTableTableManager(
    _$AppDatabase db,
    $CustomRoutingProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomRoutingProfilesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CustomRoutingProfilesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CustomRoutingProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> data = const Value.absent(),
          }) => CustomRoutingProfilesCompanion(id: id, name: name, data: data),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String data,
              }) => CustomRoutingProfilesCompanion.insert(
                id: id,
                name: name,
                data: data,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomRoutingProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomRoutingProfilesTable,
      CustomRoutingProfileData,
      $$CustomRoutingProfilesTableFilterComposer,
      $$CustomRoutingProfilesTableOrderingComposer,
      $$CustomRoutingProfilesTableAnnotationComposer,
      $$CustomRoutingProfilesTableCreateCompanionBuilder,
      $$CustomRoutingProfilesTableUpdateCompanionBuilder,
      (
        CustomRoutingProfileData,
        BaseReferences<
          _$AppDatabase,
          $CustomRoutingProfilesTable,
          CustomRoutingProfileData
        >,
      ),
      CustomRoutingProfileData,
      PrefetchHooks Function()
    >;
typedef $$ConnectionStateTableCreateCompanionBuilder =
    ConnectionStateCompanion Function({
      Value<int> id,
      Value<int> revision,
      Value<String> settingsJson,
      Value<String?> confirmedSnapshotJson,
      Value<String?> pendingApplyJson,
    });
typedef $$ConnectionStateTableUpdateCompanionBuilder =
    ConnectionStateCompanion Function({
      Value<int> id,
      Value<int> revision,
      Value<String> settingsJson,
      Value<String?> confirmedSnapshotJson,
      Value<String?> pendingApplyJson,
    });

class $$ConnectionStateTableFilterComposer
    extends Composer<_$AppDatabase, $ConnectionStateTable> {
  $$ConnectionStateTableFilterComposer({
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmedSnapshotJson => $composableBuilder(
    column: $table.confirmedSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingApplyJson => $composableBuilder(
    column: $table.pendingApplyJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConnectionStateTableOrderingComposer
    extends Composer<_$AppDatabase, $ConnectionStateTable> {
  $$ConnectionStateTableOrderingComposer({
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmedSnapshotJson => $composableBuilder(
    column: $table.confirmedSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingApplyJson => $composableBuilder(
    column: $table.pendingApplyJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConnectionStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConnectionStateTable> {
  $$ConnectionStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmedSnapshotJson => $composableBuilder(
    column: $table.confirmedSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingApplyJson => $composableBuilder(
    column: $table.pendingApplyJson,
    builder: (column) => column,
  );
}

class $$ConnectionStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConnectionStateTable,
          ConnectionStateData,
          $$ConnectionStateTableFilterComposer,
          $$ConnectionStateTableOrderingComposer,
          $$ConnectionStateTableAnnotationComposer,
          $$ConnectionStateTableCreateCompanionBuilder,
          $$ConnectionStateTableUpdateCompanionBuilder,
          (
            ConnectionStateData,
            BaseReferences<
              _$AppDatabase,
              $ConnectionStateTable,
              ConnectionStateData
            >,
          ),
          ConnectionStateData,
          PrefetchHooks Function()
        > {
  $$ConnectionStateTableTableManager(
    _$AppDatabase db,
    $ConnectionStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectionStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectionStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectionStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> settingsJson = const Value.absent(),
                Value<String?> confirmedSnapshotJson = const Value.absent(),
                Value<String?> pendingApplyJson = const Value.absent(),
              }) => ConnectionStateCompanion(
                id: id,
                revision: revision,
                settingsJson: settingsJson,
                confirmedSnapshotJson: confirmedSnapshotJson,
                pendingApplyJson: pendingApplyJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> settingsJson = const Value.absent(),
                Value<String?> confirmedSnapshotJson = const Value.absent(),
                Value<String?> pendingApplyJson = const Value.absent(),
              }) => ConnectionStateCompanion.insert(
                id: id,
                revision: revision,
                settingsJson: settingsJson,
                confirmedSnapshotJson: confirmedSnapshotJson,
                pendingApplyJson: pendingApplyJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConnectionStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConnectionStateTable,
      ConnectionStateData,
      $$ConnectionStateTableFilterComposer,
      $$ConnectionStateTableOrderingComposer,
      $$ConnectionStateTableAnnotationComposer,
      $$ConnectionStateTableCreateCompanionBuilder,
      $$ConnectionStateTableUpdateCompanionBuilder,
      (
        ConnectionStateData,
        BaseReferences<
          _$AppDatabase,
          $ConnectionStateTable,
          ConnectionStateData
        >,
      ),
      ConnectionStateData,
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
  $$CustomRoutingProfilesTableTableManager get customRoutingProfiles =>
      $$CustomRoutingProfilesTableTableManager(_db, _db.customRoutingProfiles);
  $$ConnectionStateTableTableManager get connectionState =>
      $$ConnectionStateTableTableManager(_db, _db.connectionState);
}
