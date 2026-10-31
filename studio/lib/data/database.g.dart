// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BoxesTable extends Boxes with TableInfo<$BoxesTable, BoxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoxesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _madeMeta = const VerificationMeta('made');
  @override
  late final GeneratedColumn<DateTime> made = GeneratedColumn<DateTime>(
    'made',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, made, number, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boxes';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('made')) {
      context.handle(
        _madeMeta,
        made.isAcceptableOrUnknown(data['made']!, _madeMeta),
      );
    } else if (isInserting) {
      context.missing(_madeMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      made: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}made'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
    );
  }

  @override
  $BoxesTable createAlias(String alias) {
    return $BoxesTable(attachedDatabase, alias);
  }
}

class BoxRow extends DataClass implements Insertable<BoxRow> {
  final int id;
  final DateTime made;
  final int? number;
  final String? name;
  const BoxRow({required this.id, required this.made, this.number, this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['made'] = Variable<DateTime>(made);
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<int>(number);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    return map;
  }

  BoxesCompanion toCompanion(bool nullToAbsent) {
    return BoxesCompanion(
      id: Value(id),
      made: Value(made),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
    );
  }

  factory BoxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoxRow(
      id: serializer.fromJson<int>(json['id']),
      made: serializer.fromJson<DateTime>(json['made']),
      number: serializer.fromJson<int?>(json['number']),
      name: serializer.fromJson<String?>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'made': serializer.toJson<DateTime>(made),
      'number': serializer.toJson<int?>(number),
      'name': serializer.toJson<String?>(name),
    };
  }

  BoxRow copyWith({
    int? id,
    DateTime? made,
    Value<int?> number = const Value.absent(),
    Value<String?> name = const Value.absent(),
  }) => BoxRow(
    id: id ?? this.id,
    made: made ?? this.made,
    number: number.present ? number.value : this.number,
    name: name.present ? name.value : this.name,
  );
  BoxRow copyWithCompanion(BoxesCompanion data) {
    return BoxRow(
      id: data.id.present ? data.id.value : this.id,
      made: data.made.present ? data.made.value : this.made,
      number: data.number.present ? data.number.value : this.number,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoxRow(')
          ..write('id: $id, ')
          ..write('made: $made, ')
          ..write('number: $number, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, made, number, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoxRow &&
          other.id == this.id &&
          other.made == this.made &&
          other.number == this.number &&
          other.name == this.name);
}

class BoxesCompanion extends UpdateCompanion<BoxRow> {
  final Value<int> id;
  final Value<DateTime> made;
  final Value<int?> number;
  final Value<String?> name;
  const BoxesCompanion({
    this.id = const Value.absent(),
    this.made = const Value.absent(),
    this.number = const Value.absent(),
    this.name = const Value.absent(),
  });
  BoxesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime made,
    this.number = const Value.absent(),
    this.name = const Value.absent(),
  }) : made = Value(made);
  static Insertable<BoxRow> custom({
    Expression<int>? id,
    Expression<DateTime>? made,
    Expression<int>? number,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (made != null) 'made': made,
      if (number != null) 'number': number,
      if (name != null) 'name': name,
    });
  }

  BoxesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? made,
    Value<int?>? number,
    Value<String?>? name,
  }) {
    return BoxesCompanion(
      id: id ?? this.id,
      made: made ?? this.made,
      number: number ?? this.number,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (made.present) {
      map['made'] = Variable<DateTime>(made.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoxesCompanion(')
          ..write('id: $id, ')
          ..write('made: $made, ')
          ..write('number: $number, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $ClothsTable extends Cloths with TableInfo<$ClothsTable, ClothRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClothsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxMeta = const VerificationMeta('box');
  @override
  late final GeneratedColumn<int> box = GeneratedColumn<int>(
    'box',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES boxes (id)',
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
  static const VerificationMeta _fabricMeta = const VerificationMeta('fabric');
  @override
  late final GeneratedColumn<String> fabric = GeneratedColumn<String>(
    'fabric',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _piecesMeta = const VerificationMeta('pieces');
  @override
  late final GeneratedColumn<int> pieces = GeneratedColumn<int>(
    'pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lMeta = const VerificationMeta('l');
  @override
  late final GeneratedColumn<double> l = GeneratedColumn<double>(
    'l',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aMeta = const VerificationMeta('a');
  @override
  late final GeneratedColumn<double> a = GeneratedColumn<double>(
    'a',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bMeta = const VerificationMeta('b');
  @override
  late final GeneratedColumn<double> b = GeneratedColumn<double>(
    'b',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spreadMeta = const VerificationMeta('spread');
  @override
  late final GeneratedColumn<double> spread = GeneratedColumn<double>(
    'spread',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colourMeta = const VerificationMeta('colour');
  @override
  late final GeneratedColumn<String> colour = GeneratedColumn<String>(
    'colour',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoMeta = const VerificationMeta('photo');
  @override
  late final GeneratedColumn<Uint8List> photo = GeneratedColumn<Uint8List>(
    'photo',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<DateTime> added = GeneratedColumn<DateTime>(
    'added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoNumberMeta = const VerificationMeta(
    'photoNumber',
  );
  @override
  late final GeneratedColumn<int> photoNumber = GeneratedColumn<int>(
    'photo_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    box,
    name,
    fabric,
    pieces,
    l,
    a,
    b,
    spread,
    colour,
    photo,
    version,
    added,
    photoNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cloths';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClothRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('box')) {
      context.handle(
        _boxMeta,
        box.isAcceptableOrUnknown(data['box']!, _boxMeta),
      );
    } else if (isInserting) {
      context.missing(_boxMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('fabric')) {
      context.handle(
        _fabricMeta,
        fabric.isAcceptableOrUnknown(data['fabric']!, _fabricMeta),
      );
    } else if (isInserting) {
      context.missing(_fabricMeta);
    }
    if (data.containsKey('pieces')) {
      context.handle(
        _piecesMeta,
        pieces.isAcceptableOrUnknown(data['pieces']!, _piecesMeta),
      );
    } else if (isInserting) {
      context.missing(_piecesMeta);
    }
    if (data.containsKey('l')) {
      context.handle(_lMeta, l.isAcceptableOrUnknown(data['l']!, _lMeta));
    } else if (isInserting) {
      context.missing(_lMeta);
    }
    if (data.containsKey('a')) {
      context.handle(_aMeta, a.isAcceptableOrUnknown(data['a']!, _aMeta));
    } else if (isInserting) {
      context.missing(_aMeta);
    }
    if (data.containsKey('b')) {
      context.handle(_bMeta, b.isAcceptableOrUnknown(data['b']!, _bMeta));
    } else if (isInserting) {
      context.missing(_bMeta);
    }
    if (data.containsKey('spread')) {
      context.handle(
        _spreadMeta,
        spread.isAcceptableOrUnknown(data['spread']!, _spreadMeta),
      );
    } else if (isInserting) {
      context.missing(_spreadMeta);
    }
    if (data.containsKey('colour')) {
      context.handle(
        _colourMeta,
        colour.isAcceptableOrUnknown(data['colour']!, _colourMeta),
      );
    } else if (isInserting) {
      context.missing(_colourMeta);
    }
    if (data.containsKey('photo')) {
      context.handle(
        _photoMeta,
        photo.isAcceptableOrUnknown(data['photo']!, _photoMeta),
      );
    } else if (isInserting) {
      context.missing(_photoMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('added')) {
      context.handle(
        _addedMeta,
        added.isAcceptableOrUnknown(data['added']!, _addedMeta),
      );
    } else if (isInserting) {
      context.missing(_addedMeta);
    }
    if (data.containsKey('photo_number')) {
      context.handle(
        _photoNumberMeta,
        photoNumber.isAcceptableOrUnknown(
          data['photo_number']!,
          _photoNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClothRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClothRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      box: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      fabric: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fabric'],
      )!,
      pieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pieces'],
      )!,
      l: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}l'],
      )!,
      a: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}a'],
      )!,
      b: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}b'],
      )!,
      spread: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}spread'],
      )!,
      colour: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colour'],
      )!,
      photo: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}photo'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      added: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added'],
      )!,
      photoNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_number'],
      )!,
    );
  }

  @override
  $ClothsTable createAlias(String alias) {
    return $ClothsTable(attachedDatabase, alias);
  }
}

class ClothRow extends DataClass implements Insertable<ClothRow> {
  final String id;
  final int box;
  final String name;
  final String fabric;
  final int pieces;
  final double l;
  final double a;
  final double b;
  final double spread;
  final String colour;
  final Uint8List photo;
  final int version;
  final DateTime added;
  final int photoNumber;
  const ClothRow({
    required this.id,
    required this.box,
    required this.name,
    required this.fabric,
    required this.pieces,
    required this.l,
    required this.a,
    required this.b,
    required this.spread,
    required this.colour,
    required this.photo,
    required this.version,
    required this.added,
    required this.photoNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['box'] = Variable<int>(box);
    map['name'] = Variable<String>(name);
    map['fabric'] = Variable<String>(fabric);
    map['pieces'] = Variable<int>(pieces);
    map['l'] = Variable<double>(l);
    map['a'] = Variable<double>(a);
    map['b'] = Variable<double>(b);
    map['spread'] = Variable<double>(spread);
    map['colour'] = Variable<String>(colour);
    map['photo'] = Variable<Uint8List>(photo);
    map['version'] = Variable<int>(version);
    map['added'] = Variable<DateTime>(added);
    map['photo_number'] = Variable<int>(photoNumber);
    return map;
  }

  ClothsCompanion toCompanion(bool nullToAbsent) {
    return ClothsCompanion(
      id: Value(id),
      box: Value(box),
      name: Value(name),
      fabric: Value(fabric),
      pieces: Value(pieces),
      l: Value(l),
      a: Value(a),
      b: Value(b),
      spread: Value(spread),
      colour: Value(colour),
      photo: Value(photo),
      version: Value(version),
      added: Value(added),
      photoNumber: Value(photoNumber),
    );
  }

  factory ClothRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClothRow(
      id: serializer.fromJson<String>(json['id']),
      box: serializer.fromJson<int>(json['box']),
      name: serializer.fromJson<String>(json['name']),
      fabric: serializer.fromJson<String>(json['fabric']),
      pieces: serializer.fromJson<int>(json['pieces']),
      l: serializer.fromJson<double>(json['l']),
      a: serializer.fromJson<double>(json['a']),
      b: serializer.fromJson<double>(json['b']),
      spread: serializer.fromJson<double>(json['spread']),
      colour: serializer.fromJson<String>(json['colour']),
      photo: serializer.fromJson<Uint8List>(json['photo']),
      version: serializer.fromJson<int>(json['version']),
      added: serializer.fromJson<DateTime>(json['added']),
      photoNumber: serializer.fromJson<int>(json['photoNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'box': serializer.toJson<int>(box),
      'name': serializer.toJson<String>(name),
      'fabric': serializer.toJson<String>(fabric),
      'pieces': serializer.toJson<int>(pieces),
      'l': serializer.toJson<double>(l),
      'a': serializer.toJson<double>(a),
      'b': serializer.toJson<double>(b),
      'spread': serializer.toJson<double>(spread),
      'colour': serializer.toJson<String>(colour),
      'photo': serializer.toJson<Uint8List>(photo),
      'version': serializer.toJson<int>(version),
      'added': serializer.toJson<DateTime>(added),
      'photoNumber': serializer.toJson<int>(photoNumber),
    };
  }

  ClothRow copyWith({
    String? id,
    int? box,
    String? name,
    String? fabric,
    int? pieces,
    double? l,
    double? a,
    double? b,
    double? spread,
    String? colour,
    Uint8List? photo,
    int? version,
    DateTime? added,
    int? photoNumber,
  }) => ClothRow(
    id: id ?? this.id,
    box: box ?? this.box,
    name: name ?? this.name,
    fabric: fabric ?? this.fabric,
    pieces: pieces ?? this.pieces,
    l: l ?? this.l,
    a: a ?? this.a,
    b: b ?? this.b,
    spread: spread ?? this.spread,
    colour: colour ?? this.colour,
    photo: photo ?? this.photo,
    version: version ?? this.version,
    added: added ?? this.added,
    photoNumber: photoNumber ?? this.photoNumber,
  );
  ClothRow copyWithCompanion(ClothsCompanion data) {
    return ClothRow(
      id: data.id.present ? data.id.value : this.id,
      box: data.box.present ? data.box.value : this.box,
      name: data.name.present ? data.name.value : this.name,
      fabric: data.fabric.present ? data.fabric.value : this.fabric,
      pieces: data.pieces.present ? data.pieces.value : this.pieces,
      l: data.l.present ? data.l.value : this.l,
      a: data.a.present ? data.a.value : this.a,
      b: data.b.present ? data.b.value : this.b,
      spread: data.spread.present ? data.spread.value : this.spread,
      colour: data.colour.present ? data.colour.value : this.colour,
      photo: data.photo.present ? data.photo.value : this.photo,
      version: data.version.present ? data.version.value : this.version,
      added: data.added.present ? data.added.value : this.added,
      photoNumber: data.photoNumber.present
          ? data.photoNumber.value
          : this.photoNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClothRow(')
          ..write('id: $id, ')
          ..write('box: $box, ')
          ..write('name: $name, ')
          ..write('fabric: $fabric, ')
          ..write('pieces: $pieces, ')
          ..write('l: $l, ')
          ..write('a: $a, ')
          ..write('b: $b, ')
          ..write('spread: $spread, ')
          ..write('colour: $colour, ')
          ..write('photo: $photo, ')
          ..write('version: $version, ')
          ..write('added: $added, ')
          ..write('photoNumber: $photoNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    box,
    name,
    fabric,
    pieces,
    l,
    a,
    b,
    spread,
    colour,
    $driftBlobEquality.hash(photo),
    version,
    added,
    photoNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClothRow &&
          other.id == this.id &&
          other.box == this.box &&
          other.name == this.name &&
          other.fabric == this.fabric &&
          other.pieces == this.pieces &&
          other.l == this.l &&
          other.a == this.a &&
          other.b == this.b &&
          other.spread == this.spread &&
          other.colour == this.colour &&
          $driftBlobEquality.equals(other.photo, this.photo) &&
          other.version == this.version &&
          other.added == this.added &&
          other.photoNumber == this.photoNumber);
}

class ClothsCompanion extends UpdateCompanion<ClothRow> {
  final Value<String> id;
  final Value<int> box;
  final Value<String> name;
  final Value<String> fabric;
  final Value<int> pieces;
  final Value<double> l;
  final Value<double> a;
  final Value<double> b;
  final Value<double> spread;
  final Value<String> colour;
  final Value<Uint8List> photo;
  final Value<int> version;
  final Value<DateTime> added;
  final Value<int> photoNumber;
  final Value<int> rowid;
  const ClothsCompanion({
    this.id = const Value.absent(),
    this.box = const Value.absent(),
    this.name = const Value.absent(),
    this.fabric = const Value.absent(),
    this.pieces = const Value.absent(),
    this.l = const Value.absent(),
    this.a = const Value.absent(),
    this.b = const Value.absent(),
    this.spread = const Value.absent(),
    this.colour = const Value.absent(),
    this.photo = const Value.absent(),
    this.version = const Value.absent(),
    this.added = const Value.absent(),
    this.photoNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClothsCompanion.insert({
    required String id,
    required int box,
    required String name,
    required String fabric,
    required int pieces,
    required double l,
    required double a,
    required double b,
    required double spread,
    required String colour,
    required Uint8List photo,
    this.version = const Value.absent(),
    required DateTime added,
    this.photoNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       box = Value(box),
       name = Value(name),
       fabric = Value(fabric),
       pieces = Value(pieces),
       l = Value(l),
       a = Value(a),
       b = Value(b),
       spread = Value(spread),
       colour = Value(colour),
       photo = Value(photo),
       added = Value(added);
  static Insertable<ClothRow> custom({
    Expression<String>? id,
    Expression<int>? box,
    Expression<String>? name,
    Expression<String>? fabric,
    Expression<int>? pieces,
    Expression<double>? l,
    Expression<double>? a,
    Expression<double>? b,
    Expression<double>? spread,
    Expression<String>? colour,
    Expression<Uint8List>? photo,
    Expression<int>? version,
    Expression<DateTime>? added,
    Expression<int>? photoNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (box != null) 'box': box,
      if (name != null) 'name': name,
      if (fabric != null) 'fabric': fabric,
      if (pieces != null) 'pieces': pieces,
      if (l != null) 'l': l,
      if (a != null) 'a': a,
      if (b != null) 'b': b,
      if (spread != null) 'spread': spread,
      if (colour != null) 'colour': colour,
      if (photo != null) 'photo': photo,
      if (version != null) 'version': version,
      if (added != null) 'added': added,
      if (photoNumber != null) 'photo_number': photoNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClothsCompanion copyWith({
    Value<String>? id,
    Value<int>? box,
    Value<String>? name,
    Value<String>? fabric,
    Value<int>? pieces,
    Value<double>? l,
    Value<double>? a,
    Value<double>? b,
    Value<double>? spread,
    Value<String>? colour,
    Value<Uint8List>? photo,
    Value<int>? version,
    Value<DateTime>? added,
    Value<int>? photoNumber,
    Value<int>? rowid,
  }) {
    return ClothsCompanion(
      id: id ?? this.id,
      box: box ?? this.box,
      name: name ?? this.name,
      fabric: fabric ?? this.fabric,
      pieces: pieces ?? this.pieces,
      l: l ?? this.l,
      a: a ?? this.a,
      b: b ?? this.b,
      spread: spread ?? this.spread,
      colour: colour ?? this.colour,
      photo: photo ?? this.photo,
      version: version ?? this.version,
      added: added ?? this.added,
      photoNumber: photoNumber ?? this.photoNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (box.present) {
      map['box'] = Variable<int>(box.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (fabric.present) {
      map['fabric'] = Variable<String>(fabric.value);
    }
    if (pieces.present) {
      map['pieces'] = Variable<int>(pieces.value);
    }
    if (l.present) {
      map['l'] = Variable<double>(l.value);
    }
    if (a.present) {
      map['a'] = Variable<double>(a.value);
    }
    if (b.present) {
      map['b'] = Variable<double>(b.value);
    }
    if (spread.present) {
      map['spread'] = Variable<double>(spread.value);
    }
    if (colour.present) {
      map['colour'] = Variable<String>(colour.value);
    }
    if (photo.present) {
      map['photo'] = Variable<Uint8List>(photo.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (added.present) {
      map['added'] = Variable<DateTime>(added.value);
    }
    if (photoNumber.present) {
      map['photo_number'] = Variable<int>(photoNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClothsCompanion(')
          ..write('id: $id, ')
          ..write('box: $box, ')
          ..write('name: $name, ')
          ..write('fabric: $fabric, ')
          ..write('pieces: $pieces, ')
          ..write('l: $l, ')
          ..write('a: $a, ')
          ..write('b: $b, ')
          ..write('spread: $spread, ')
          ..write('colour: $colour, ')
          ..write('photo: $photo, ')
          ..write('version: $version, ')
          ..write('added: $added, ')
          ..write('photoNumber: $photoNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DesignsTable extends Designs with TableInfo<$DesignsTable, DesignRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DesignsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _layoutMeta = const VerificationMeta('layout');
  @override
  late final GeneratedColumn<String> layout = GeneratedColumn<String>(
    'layout',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mountMeta = const VerificationMeta('mount');
  @override
  late final GeneratedColumn<String> mount = GeneratedColumn<String>(
    'mount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxMeta = const VerificationMeta('box');
  @override
  late final GeneratedColumn<int> box = GeneratedColumn<int>(
    'box',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seedMeta = const VerificationMeta('seed');
  @override
  late final GeneratedColumn<int> seed = GeneratedColumn<int>(
    'seed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedMeta = const VerificationMeta(
    'started',
  );
  @override
  late final GeneratedColumn<String> started = GeneratedColumn<String>(
    'started',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSolveMeta = const VerificationMeta(
    'firstSolve',
  );
  @override
  late final GeneratedColumn<String> firstSolve = GeneratedColumn<String>(
    'first_solve',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gridMeta = const VerificationMeta('grid');
  @override
  late final GeneratedColumn<String> grid = GeneratedColumn<String>(
    'grid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedMeta = const VerificationMeta('saved');
  @override
  late final GeneratedColumn<DateTime> saved = GeneratedColumn<DateTime>(
    'saved',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colsMeta = const VerificationMeta('cols');
  @override
  late final GeneratedColumn<int> cols = GeneratedColumn<int>(
    'cols',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    layout,
    mount,
    box,
    seed,
    started,
    firstSolve,
    grid,
    saved,
    cols,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'designs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DesignRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('layout')) {
      context.handle(
        _layoutMeta,
        layout.isAcceptableOrUnknown(data['layout']!, _layoutMeta),
      );
    } else if (isInserting) {
      context.missing(_layoutMeta);
    }
    if (data.containsKey('mount')) {
      context.handle(
        _mountMeta,
        mount.isAcceptableOrUnknown(data['mount']!, _mountMeta),
      );
    } else if (isInserting) {
      context.missing(_mountMeta);
    }
    if (data.containsKey('box')) {
      context.handle(
        _boxMeta,
        box.isAcceptableOrUnknown(data['box']!, _boxMeta),
      );
    }
    if (data.containsKey('seed')) {
      context.handle(
        _seedMeta,
        seed.isAcceptableOrUnknown(data['seed']!, _seedMeta),
      );
    }
    if (data.containsKey('started')) {
      context.handle(
        _startedMeta,
        started.isAcceptableOrUnknown(data['started']!, _startedMeta),
      );
    }
    if (data.containsKey('first_solve')) {
      context.handle(
        _firstSolveMeta,
        firstSolve.isAcceptableOrUnknown(data['first_solve']!, _firstSolveMeta),
      );
    }
    if (data.containsKey('grid')) {
      context.handle(
        _gridMeta,
        grid.isAcceptableOrUnknown(data['grid']!, _gridMeta),
      );
    } else if (isInserting) {
      context.missing(_gridMeta);
    }
    if (data.containsKey('saved')) {
      context.handle(
        _savedMeta,
        saved.isAcceptableOrUnknown(data['saved']!, _savedMeta),
      );
    } else if (isInserting) {
      context.missing(_savedMeta);
    }
    if (data.containsKey('cols')) {
      context.handle(
        _colsMeta,
        cols.isAcceptableOrUnknown(data['cols']!, _colsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DesignRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DesignRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      layout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layout'],
      )!,
      mount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mount'],
      )!,
      box: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box'],
      ),
      seed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed'],
      ),
      started: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started'],
      ),
      firstSolve: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_solve'],
      ),
      grid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grid'],
      )!,
      saved: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved'],
      )!,
      cols: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cols'],
      ),
    );
  }

  @override
  $DesignsTable createAlias(String alias) {
    return $DesignsTable(attachedDatabase, alias);
  }
}

class DesignRow extends DataClass implements Insertable<DesignRow> {
  final String id;
  final String name;
  final String layout;
  final String mount;
  final int? box;
  final int? seed;
  final String? started;
  final String? firstSolve;
  final String grid;
  final DateTime saved;
  final int? cols;
  const DesignRow({
    required this.id,
    required this.name,
    required this.layout,
    required this.mount,
    this.box,
    this.seed,
    this.started,
    this.firstSolve,
    required this.grid,
    required this.saved,
    this.cols,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['layout'] = Variable<String>(layout);
    map['mount'] = Variable<String>(mount);
    if (!nullToAbsent || box != null) {
      map['box'] = Variable<int>(box);
    }
    if (!nullToAbsent || seed != null) {
      map['seed'] = Variable<int>(seed);
    }
    if (!nullToAbsent || started != null) {
      map['started'] = Variable<String>(started);
    }
    if (!nullToAbsent || firstSolve != null) {
      map['first_solve'] = Variable<String>(firstSolve);
    }
    map['grid'] = Variable<String>(grid);
    map['saved'] = Variable<DateTime>(saved);
    if (!nullToAbsent || cols != null) {
      map['cols'] = Variable<int>(cols);
    }
    return map;
  }

  DesignsCompanion toCompanion(bool nullToAbsent) {
    return DesignsCompanion(
      id: Value(id),
      name: Value(name),
      layout: Value(layout),
      mount: Value(mount),
      box: box == null && nullToAbsent ? const Value.absent() : Value(box),
      seed: seed == null && nullToAbsent ? const Value.absent() : Value(seed),
      started: started == null && nullToAbsent
          ? const Value.absent()
          : Value(started),
      firstSolve: firstSolve == null && nullToAbsent
          ? const Value.absent()
          : Value(firstSolve),
      grid: Value(grid),
      saved: Value(saved),
      cols: cols == null && nullToAbsent ? const Value.absent() : Value(cols),
    );
  }

  factory DesignRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DesignRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      layout: serializer.fromJson<String>(json['layout']),
      mount: serializer.fromJson<String>(json['mount']),
      box: serializer.fromJson<int?>(json['box']),
      seed: serializer.fromJson<int?>(json['seed']),
      started: serializer.fromJson<String?>(json['started']),
      firstSolve: serializer.fromJson<String?>(json['firstSolve']),
      grid: serializer.fromJson<String>(json['grid']),
      saved: serializer.fromJson<DateTime>(json['saved']),
      cols: serializer.fromJson<int?>(json['cols']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'layout': serializer.toJson<String>(layout),
      'mount': serializer.toJson<String>(mount),
      'box': serializer.toJson<int?>(box),
      'seed': serializer.toJson<int?>(seed),
      'started': serializer.toJson<String?>(started),
      'firstSolve': serializer.toJson<String?>(firstSolve),
      'grid': serializer.toJson<String>(grid),
      'saved': serializer.toJson<DateTime>(saved),
      'cols': serializer.toJson<int?>(cols),
    };
  }

  DesignRow copyWith({
    String? id,
    String? name,
    String? layout,
    String? mount,
    Value<int?> box = const Value.absent(),
    Value<int?> seed = const Value.absent(),
    Value<String?> started = const Value.absent(),
    Value<String?> firstSolve = const Value.absent(),
    String? grid,
    DateTime? saved,
    Value<int?> cols = const Value.absent(),
  }) => DesignRow(
    id: id ?? this.id,
    name: name ?? this.name,
    layout: layout ?? this.layout,
    mount: mount ?? this.mount,
    box: box.present ? box.value : this.box,
    seed: seed.present ? seed.value : this.seed,
    started: started.present ? started.value : this.started,
    firstSolve: firstSolve.present ? firstSolve.value : this.firstSolve,
    grid: grid ?? this.grid,
    saved: saved ?? this.saved,
    cols: cols.present ? cols.value : this.cols,
  );
  DesignRow copyWithCompanion(DesignsCompanion data) {
    return DesignRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      layout: data.layout.present ? data.layout.value : this.layout,
      mount: data.mount.present ? data.mount.value : this.mount,
      box: data.box.present ? data.box.value : this.box,
      seed: data.seed.present ? data.seed.value : this.seed,
      started: data.started.present ? data.started.value : this.started,
      firstSolve: data.firstSolve.present
          ? data.firstSolve.value
          : this.firstSolve,
      grid: data.grid.present ? data.grid.value : this.grid,
      saved: data.saved.present ? data.saved.value : this.saved,
      cols: data.cols.present ? data.cols.value : this.cols,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DesignRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('layout: $layout, ')
          ..write('mount: $mount, ')
          ..write('box: $box, ')
          ..write('seed: $seed, ')
          ..write('started: $started, ')
          ..write('firstSolve: $firstSolve, ')
          ..write('grid: $grid, ')
          ..write('saved: $saved, ')
          ..write('cols: $cols')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    layout,
    mount,
    box,
    seed,
    started,
    firstSolve,
    grid,
    saved,
    cols,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DesignRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.layout == this.layout &&
          other.mount == this.mount &&
          other.box == this.box &&
          other.seed == this.seed &&
          other.started == this.started &&
          other.firstSolve == this.firstSolve &&
          other.grid == this.grid &&
          other.saved == this.saved &&
          other.cols == this.cols);
}

class DesignsCompanion extends UpdateCompanion<DesignRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> layout;
  final Value<String> mount;
  final Value<int?> box;
  final Value<int?> seed;
  final Value<String?> started;
  final Value<String?> firstSolve;
  final Value<String> grid;
  final Value<DateTime> saved;
  final Value<int?> cols;
  final Value<int> rowid;
  const DesignsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.layout = const Value.absent(),
    this.mount = const Value.absent(),
    this.box = const Value.absent(),
    this.seed = const Value.absent(),
    this.started = const Value.absent(),
    this.firstSolve = const Value.absent(),
    this.grid = const Value.absent(),
    this.saved = const Value.absent(),
    this.cols = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DesignsCompanion.insert({
    required String id,
    required String name,
    required String layout,
    required String mount,
    this.box = const Value.absent(),
    this.seed = const Value.absent(),
    this.started = const Value.absent(),
    this.firstSolve = const Value.absent(),
    required String grid,
    required DateTime saved,
    this.cols = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       layout = Value(layout),
       mount = Value(mount),
       grid = Value(grid),
       saved = Value(saved);
  static Insertable<DesignRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? layout,
    Expression<String>? mount,
    Expression<int>? box,
    Expression<int>? seed,
    Expression<String>? started,
    Expression<String>? firstSolve,
    Expression<String>? grid,
    Expression<DateTime>? saved,
    Expression<int>? cols,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (layout != null) 'layout': layout,
      if (mount != null) 'mount': mount,
      if (box != null) 'box': box,
      if (seed != null) 'seed': seed,
      if (started != null) 'started': started,
      if (firstSolve != null) 'first_solve': firstSolve,
      if (grid != null) 'grid': grid,
      if (saved != null) 'saved': saved,
      if (cols != null) 'cols': cols,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DesignsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? layout,
    Value<String>? mount,
    Value<int?>? box,
    Value<int?>? seed,
    Value<String?>? started,
    Value<String?>? firstSolve,
    Value<String>? grid,
    Value<DateTime>? saved,
    Value<int?>? cols,
    Value<int>? rowid,
  }) {
    return DesignsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      layout: layout ?? this.layout,
      mount: mount ?? this.mount,
      box: box ?? this.box,
      seed: seed ?? this.seed,
      started: started ?? this.started,
      firstSolve: firstSolve ?? this.firstSolve,
      grid: grid ?? this.grid,
      saved: saved ?? this.saved,
      cols: cols ?? this.cols,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (layout.present) {
      map['layout'] = Variable<String>(layout.value);
    }
    if (mount.present) {
      map['mount'] = Variable<String>(mount.value);
    }
    if (box.present) {
      map['box'] = Variable<int>(box.value);
    }
    if (seed.present) {
      map['seed'] = Variable<int>(seed.value);
    }
    if (started.present) {
      map['started'] = Variable<String>(started.value);
    }
    if (firstSolve.present) {
      map['first_solve'] = Variable<String>(firstSolve.value);
    }
    if (grid.present) {
      map['grid'] = Variable<String>(grid.value);
    }
    if (saved.present) {
      map['saved'] = Variable<DateTime>(saved.value);
    }
    if (cols.present) {
      map['cols'] = Variable<int>(cols.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DesignsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('layout: $layout, ')
          ..write('mount: $mount, ')
          ..write('box: $box, ')
          ..write('seed: $seed, ')
          ..write('started: $started, ')
          ..write('firstSolve: $firstSolve, ')
          ..write('grid: $grid, ')
          ..write('saved: $saved, ')
          ..write('cols: $cols, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PicturesTable extends Pictures
    with TableInfo<$PicturesTable, PictureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PicturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _designMeta = const VerificationMeta('design');
  @override
  late final GeneratedColumn<String> design = GeneratedColumn<String>(
    'design',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _madeMeta = const VerificationMeta('made');
  @override
  late final GeneratedColumn<DateTime> made = GeneratedColumn<DateTime>(
    'made',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedMeta = const VerificationMeta('saved');
  @override
  late final GeneratedColumn<DateTime> saved = GeneratedColumn<DateTime>(
    'saved',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pngMeta = const VerificationMeta('png');
  @override
  late final GeneratedColumn<Uint8List> png = GeneratedColumn<Uint8List>(
    'png',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbMeta = const VerificationMeta('thumb');
  @override
  late final GeneratedColumn<Uint8List> thumb = GeneratedColumn<Uint8List>(
    'thumb',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    design,
    name,
    made,
    saved,
    png,
    thumb,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pictures';
  @override
  VerificationContext validateIntegrity(
    Insertable<PictureRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('design')) {
      context.handle(
        _designMeta,
        design.isAcceptableOrUnknown(data['design']!, _designMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('made')) {
      context.handle(
        _madeMeta,
        made.isAcceptableOrUnknown(data['made']!, _madeMeta),
      );
    } else if (isInserting) {
      context.missing(_madeMeta);
    }
    if (data.containsKey('saved')) {
      context.handle(
        _savedMeta,
        saved.isAcceptableOrUnknown(data['saved']!, _savedMeta),
      );
    } else if (isInserting) {
      context.missing(_savedMeta);
    }
    if (data.containsKey('png')) {
      context.handle(
        _pngMeta,
        png.isAcceptableOrUnknown(data['png']!, _pngMeta),
      );
    } else if (isInserting) {
      context.missing(_pngMeta);
    }
    if (data.containsKey('thumb')) {
      context.handle(
        _thumbMeta,
        thumb.isAcceptableOrUnknown(data['thumb']!, _thumbMeta),
      );
    } else if (isInserting) {
      context.missing(_thumbMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PictureRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PictureRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      design: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}design'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      made: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}made'],
      )!,
      saved: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved'],
      )!,
      png: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}png'],
      )!,
      thumb: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}thumb'],
      )!,
    );
  }

  @override
  $PicturesTable createAlias(String alias) {
    return $PicturesTable(attachedDatabase, alias);
  }
}

class PictureRow extends DataClass implements Insertable<PictureRow> {
  final int id;
  final String? design;
  final String name;
  final DateTime made;
  final DateTime saved;
  final Uint8List png;
  final Uint8List thumb;
  const PictureRow({
    required this.id,
    this.design,
    required this.name,
    required this.made,
    required this.saved,
    required this.png,
    required this.thumb,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || design != null) {
      map['design'] = Variable<String>(design);
    }
    map['name'] = Variable<String>(name);
    map['made'] = Variable<DateTime>(made);
    map['saved'] = Variable<DateTime>(saved);
    map['png'] = Variable<Uint8List>(png);
    map['thumb'] = Variable<Uint8List>(thumb);
    return map;
  }

  PicturesCompanion toCompanion(bool nullToAbsent) {
    return PicturesCompanion(
      id: Value(id),
      design: design == null && nullToAbsent
          ? const Value.absent()
          : Value(design),
      name: Value(name),
      made: Value(made),
      saved: Value(saved),
      png: Value(png),
      thumb: Value(thumb),
    );
  }

  factory PictureRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PictureRow(
      id: serializer.fromJson<int>(json['id']),
      design: serializer.fromJson<String?>(json['design']),
      name: serializer.fromJson<String>(json['name']),
      made: serializer.fromJson<DateTime>(json['made']),
      saved: serializer.fromJson<DateTime>(json['saved']),
      png: serializer.fromJson<Uint8List>(json['png']),
      thumb: serializer.fromJson<Uint8List>(json['thumb']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'design': serializer.toJson<String?>(design),
      'name': serializer.toJson<String>(name),
      'made': serializer.toJson<DateTime>(made),
      'saved': serializer.toJson<DateTime>(saved),
      'png': serializer.toJson<Uint8List>(png),
      'thumb': serializer.toJson<Uint8List>(thumb),
    };
  }

  PictureRow copyWith({
    int? id,
    Value<String?> design = const Value.absent(),
    String? name,
    DateTime? made,
    DateTime? saved,
    Uint8List? png,
    Uint8List? thumb,
  }) => PictureRow(
    id: id ?? this.id,
    design: design.present ? design.value : this.design,
    name: name ?? this.name,
    made: made ?? this.made,
    saved: saved ?? this.saved,
    png: png ?? this.png,
    thumb: thumb ?? this.thumb,
  );
  PictureRow copyWithCompanion(PicturesCompanion data) {
    return PictureRow(
      id: data.id.present ? data.id.value : this.id,
      design: data.design.present ? data.design.value : this.design,
      name: data.name.present ? data.name.value : this.name,
      made: data.made.present ? data.made.value : this.made,
      saved: data.saved.present ? data.saved.value : this.saved,
      png: data.png.present ? data.png.value : this.png,
      thumb: data.thumb.present ? data.thumb.value : this.thumb,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PictureRow(')
          ..write('id: $id, ')
          ..write('design: $design, ')
          ..write('name: $name, ')
          ..write('made: $made, ')
          ..write('saved: $saved, ')
          ..write('png: $png, ')
          ..write('thumb: $thumb')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    design,
    name,
    made,
    saved,
    $driftBlobEquality.hash(png),
    $driftBlobEquality.hash(thumb),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PictureRow &&
          other.id == this.id &&
          other.design == this.design &&
          other.name == this.name &&
          other.made == this.made &&
          other.saved == this.saved &&
          $driftBlobEquality.equals(other.png, this.png) &&
          $driftBlobEquality.equals(other.thumb, this.thumb));
}

class PicturesCompanion extends UpdateCompanion<PictureRow> {
  final Value<int> id;
  final Value<String?> design;
  final Value<String> name;
  final Value<DateTime> made;
  final Value<DateTime> saved;
  final Value<Uint8List> png;
  final Value<Uint8List> thumb;
  const PicturesCompanion({
    this.id = const Value.absent(),
    this.design = const Value.absent(),
    this.name = const Value.absent(),
    this.made = const Value.absent(),
    this.saved = const Value.absent(),
    this.png = const Value.absent(),
    this.thumb = const Value.absent(),
  });
  PicturesCompanion.insert({
    this.id = const Value.absent(),
    this.design = const Value.absent(),
    required String name,
    required DateTime made,
    required DateTime saved,
    required Uint8List png,
    required Uint8List thumb,
  }) : name = Value(name),
       made = Value(made),
       saved = Value(saved),
       png = Value(png),
       thumb = Value(thumb);
  static Insertable<PictureRow> custom({
    Expression<int>? id,
    Expression<String>? design,
    Expression<String>? name,
    Expression<DateTime>? made,
    Expression<DateTime>? saved,
    Expression<Uint8List>? png,
    Expression<Uint8List>? thumb,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (design != null) 'design': design,
      if (name != null) 'name': name,
      if (made != null) 'made': made,
      if (saved != null) 'saved': saved,
      if (png != null) 'png': png,
      if (thumb != null) 'thumb': thumb,
    });
  }

  PicturesCompanion copyWith({
    Value<int>? id,
    Value<String?>? design,
    Value<String>? name,
    Value<DateTime>? made,
    Value<DateTime>? saved,
    Value<Uint8List>? png,
    Value<Uint8List>? thumb,
  }) {
    return PicturesCompanion(
      id: id ?? this.id,
      design: design ?? this.design,
      name: name ?? this.name,
      made: made ?? this.made,
      saved: saved ?? this.saved,
      png: png ?? this.png,
      thumb: thumb ?? this.thumb,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (design.present) {
      map['design'] = Variable<String>(design.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (made.present) {
      map['made'] = Variable<DateTime>(made.value);
    }
    if (saved.present) {
      map['saved'] = Variable<DateTime>(saved.value);
    }
    if (png.present) {
      map['png'] = Variable<Uint8List>(png.value);
    }
    if (thumb.present) {
      map['thumb'] = Variable<Uint8List>(thumb.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PicturesCompanion(')
          ..write('id: $id, ')
          ..write('design: $design, ')
          ..write('name: $name, ')
          ..write('made: $made, ')
          ..write('saved: $saved, ')
          ..write('png: $png, ')
          ..write('thumb: $thumb')
          ..write(')'))
        .toString();
  }
}

class $CountersTable extends Counters
    with TableInfo<$CountersTable, CounterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextMeta = const VerificationMeta('next');
  @override
  late final GeneratedColumn<int> next = GeneratedColumn<int>(
    'next',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, next];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CounterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('next')) {
      context.handle(
        _nextMeta,
        next.isAcceptableOrUnknown(data['next']!, _nextMeta),
      );
    } else if (isInserting) {
      context.missing(_nextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  CounterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CounterRow(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      next: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next'],
      )!,
    );
  }

  @override
  $CountersTable createAlias(String alias) {
    return $CountersTable(attachedDatabase, alias);
  }
}

class CounterRow extends DataClass implements Insertable<CounterRow> {
  final String name;
  final int next;
  const CounterRow({required this.name, required this.next});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['next'] = Variable<int>(next);
    return map;
  }

  CountersCompanion toCompanion(bool nullToAbsent) {
    return CountersCompanion(name: Value(name), next: Value(next));
  }

  factory CounterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CounterRow(
      name: serializer.fromJson<String>(json['name']),
      next: serializer.fromJson<int>(json['next']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'next': serializer.toJson<int>(next),
    };
  }

  CounterRow copyWith({String? name, int? next}) =>
      CounterRow(name: name ?? this.name, next: next ?? this.next);
  CounterRow copyWithCompanion(CountersCompanion data) {
    return CounterRow(
      name: data.name.present ? data.name.value : this.name,
      next: data.next.present ? data.next.value : this.next,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CounterRow(')
          ..write('name: $name, ')
          ..write('next: $next')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, next);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CounterRow &&
          other.name == this.name &&
          other.next == this.next);
}

class CountersCompanion extends UpdateCompanion<CounterRow> {
  final Value<String> name;
  final Value<int> next;
  final Value<int> rowid;
  const CountersCompanion({
    this.name = const Value.absent(),
    this.next = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CountersCompanion.insert({
    required String name,
    required int next,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       next = Value(next);
  static Insertable<CounterRow> custom({
    Expression<String>? name,
    Expression<int>? next,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (next != null) 'next': next,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CountersCompanion copyWith({
    Value<String>? name,
    Value<int>? next,
    Value<int>? rowid,
  }) {
    return CountersCompanion(
      name: name ?? this.name,
      next: next ?? this.next,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (next.present) {
      map['next'] = Variable<int>(next.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountersCompanion(')
          ..write('name: $name, ')
          ..write('next: $next, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KanthaDatabase extends GeneratedDatabase {
  _$KanthaDatabase(QueryExecutor e) : super(e);
  $KanthaDatabaseManager get managers => $KanthaDatabaseManager(this);
  late final $BoxesTable boxes = $BoxesTable(this);
  late final $ClothsTable cloths = $ClothsTable(this);
  late final $DesignsTable designs = $DesignsTable(this);
  late final $PicturesTable pictures = $PicturesTable(this);
  late final $CountersTable counters = $CountersTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    boxes,
    cloths,
    designs,
    pictures,
    counters,
    settings,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$BoxesTableCreateCompanionBuilder = BoxesCompanion Function({
  Value<int> id,
  required DateTime made,
  Value<int?> number,
  Value<String?> name,
});
typedef $$BoxesTableUpdateCompanionBuilder = BoxesCompanion Function({
  Value<int> id,
  Value<DateTime> made,
  Value<int?> number,
  Value<String?> name,
});

final class $$BoxesTableReferences
    extends BaseReferences<_$KanthaDatabase, $BoxesTable, BoxRow> {
  $$BoxesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClothsTable, List<ClothRow>> _clothsRefsTable(
    _$KanthaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cloths,
    aliasName: 'boxes__id__cloths__box',
  );

  $$ClothsTableProcessedTableManager get clothsRefs {
    final manager = $$ClothsTableTableManager(
      $_db,
      $_db.cloths,
    ).filter((f) => f.box.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_clothsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BoxesTableFilterComposer
    extends Composer<_$KanthaDatabase, $BoxesTable> {
  $$BoxesTableFilterComposer({
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

  ColumnFilters<DateTime> get made => $composableBuilder(
    column: $table.made,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> clothsRefs(
    Expression<bool> Function($$ClothsTableFilterComposer f) f,
  ) {
    final $$ClothsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cloths,
      getReferencedColumn: (t) => t.box,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClothsTableFilterComposer(
            $db: $db,
            $table: $db.cloths,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BoxesTableOrderingComposer
    extends Composer<_$KanthaDatabase, $BoxesTable> {
  $$BoxesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get made => $composableBuilder(
    column: $table.made,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BoxesTableAnnotationComposer
    extends Composer<_$KanthaDatabase, $BoxesTable> {
  $$BoxesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get made =>
      $composableBuilder(column: $table.made, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> clothsRefs<T extends Object>(
    Expression<T> Function($$ClothsTableAnnotationComposer a) f,
  ) {
    final $$ClothsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cloths,
      getReferencedColumn: (t) => t.box,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClothsTableAnnotationComposer(
            $db: $db,
            $table: $db.cloths,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BoxesTableTableManager
    extends
        RootTableManager<
          _$KanthaDatabase,
          $BoxesTable,
          BoxRow,
          $$BoxesTableFilterComposer,
          $$BoxesTableOrderingComposer,
          $$BoxesTableAnnotationComposer,
          $$BoxesTableCreateCompanionBuilder,
          $$BoxesTableUpdateCompanionBuilder,
          (BoxRow, $$BoxesTableReferences),
          BoxRow,
          PrefetchHooks Function({bool clothsRefs})
        > {
  $$BoxesTableTableManager(_$KanthaDatabase db, $BoxesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoxesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoxesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoxesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> made = const Value.absent(),
            Value<int?> number = const Value.absent(),
            Value<String?> name = const Value.absent(),
          }) => BoxesCompanion(id: id, made: made, number: number, name: name),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime made,
                Value<int?> number = const Value.absent(),
                Value<String?> name = const Value.absent(),
              }) => BoxesCompanion.insert(
                id: id,
                made: made,
                number: number,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BoxesTable, BoxRow>(table),
                  $$BoxesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clothsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (clothsRefs) db.cloths],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (clothsRefs)
                    await $_getPrefetchedData<BoxRow, $BoxesTable, ClothRow>(
                      currentTable: table,
                      referencedTable: $$BoxesTableReferences._clothsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$BoxesTableReferences(db, table, p0).clothsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.box == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BoxesTableProcessedTableManager =
    ProcessedTableManager<
      _$KanthaDatabase,
      $BoxesTable,
      BoxRow,
      $$BoxesTableFilterComposer,
      $$BoxesTableOrderingComposer,
      $$BoxesTableAnnotationComposer,
      $$BoxesTableCreateCompanionBuilder,
      $$BoxesTableUpdateCompanionBuilder,
      (BoxRow, $$BoxesTableReferences),
      BoxRow,
      PrefetchHooks Function({bool clothsRefs})
    >;
typedef $$ClothsTableCreateCompanionBuilder = ClothsCompanion Function({
  required String id,
  required int box,
  required String name,
  required String fabric,
  required int pieces,
  required double l,
  required double a,
  required double b,
  required double spread,
  required String colour,
  required Uint8List photo,
  Value<int> version,
  required DateTime added,
  Value<int> photoNumber,
  Value<int> rowid,
});
typedef $$ClothsTableUpdateCompanionBuilder = ClothsCompanion Function({
  Value<String> id,
  Value<int> box,
  Value<String> name,
  Value<String> fabric,
  Value<int> pieces,
  Value<double> l,
  Value<double> a,
  Value<double> b,
  Value<double> spread,
  Value<String> colour,
  Value<Uint8List> photo,
  Value<int> version,
  Value<DateTime> added,
  Value<int> photoNumber,
  Value<int> rowid,
});

final class $$ClothsTableReferences
    extends BaseReferences<_$KanthaDatabase, $ClothsTable, ClothRow> {
  $$ClothsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BoxesTable _boxTable(_$KanthaDatabase db) =>
      db.boxes.createAlias('cloths__box__boxes__id');

  $$BoxesTableProcessedTableManager get box {
    final $_column = $_itemColumn<int>('box')!;

    final manager = $$BoxesTableTableManager(
      $_db,
      $_db.boxes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_boxTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClothsTableFilterComposer
    extends Composer<_$KanthaDatabase, $ClothsTable> {
  $$ClothsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fabric => $composableBuilder(
    column: $table.fabric,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get l => $composableBuilder(
    column: $table.l,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get a => $composableBuilder(
    column: $table.a,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get b => $composableBuilder(
    column: $table.b,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get spread => $composableBuilder(
    column: $table.spread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colour => $composableBuilder(
    column: $table.colour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get photo => $composableBuilder(
    column: $table.photo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get photoNumber => $composableBuilder(
    column: $table.photoNumber,
    builder: (column) => ColumnFilters(column),
  );

  $$BoxesTableFilterComposer get box {
    final $$BoxesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.box,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableFilterComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClothsTableOrderingComposer
    extends Composer<_$KanthaDatabase, $ClothsTable> {
  $$ClothsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fabric => $composableBuilder(
    column: $table.fabric,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pieces => $composableBuilder(
    column: $table.pieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get l => $composableBuilder(
    column: $table.l,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get a => $composableBuilder(
    column: $table.a,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get b => $composableBuilder(
    column: $table.b,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get spread => $composableBuilder(
    column: $table.spread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colour => $composableBuilder(
    column: $table.colour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get photo => $composableBuilder(
    column: $table.photo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoNumber => $composableBuilder(
    column: $table.photoNumber,
    builder: (column) => ColumnOrderings(column),
  );

  $$BoxesTableOrderingComposer get box {
    final $$BoxesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.box,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableOrderingComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClothsTableAnnotationComposer
    extends Composer<_$KanthaDatabase, $ClothsTable> {
  $$ClothsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get fabric =>
      $composableBuilder(column: $table.fabric, builder: (column) => column);

  GeneratedColumn<int> get pieces =>
      $composableBuilder(column: $table.pieces, builder: (column) => column);

  GeneratedColumn<double> get l =>
      $composableBuilder(column: $table.l, builder: (column) => column);

  GeneratedColumn<double> get a =>
      $composableBuilder(column: $table.a, builder: (column) => column);

  GeneratedColumn<double> get b =>
      $composableBuilder(column: $table.b, builder: (column) => column);

  GeneratedColumn<double> get spread =>
      $composableBuilder(column: $table.spread, builder: (column) => column);

  GeneratedColumn<String> get colour =>
      $composableBuilder(column: $table.colour, builder: (column) => column);

  GeneratedColumn<Uint8List> get photo =>
      $composableBuilder(column: $table.photo, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get added =>
      $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<int> get photoNumber => $composableBuilder(
    column: $table.photoNumber,
    builder: (column) => column,
  );

  $$BoxesTableAnnotationComposer get box {
    final $$BoxesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.box,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableAnnotationComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClothsTableTableManager
    extends
        RootTableManager<
          _$KanthaDatabase,
          $ClothsTable,
          ClothRow,
          $$ClothsTableFilterComposer,
          $$ClothsTableOrderingComposer,
          $$ClothsTableAnnotationComposer,
          $$ClothsTableCreateCompanionBuilder,
          $$ClothsTableUpdateCompanionBuilder,
          (ClothRow, $$ClothsTableReferences),
          ClothRow,
          PrefetchHooks Function({bool box})
        > {
  $$ClothsTableTableManager(_$KanthaDatabase db, $ClothsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClothsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClothsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClothsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> box = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> fabric = const Value.absent(),
                Value<int> pieces = const Value.absent(),
                Value<double> l = const Value.absent(),
                Value<double> a = const Value.absent(),
                Value<double> b = const Value.absent(),
                Value<double> spread = const Value.absent(),
                Value<String> colour = const Value.absent(),
                Value<Uint8List> photo = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> added = const Value.absent(),
                Value<int> photoNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClothsCompanion(
                id: id,
                box: box,
                name: name,
                fabric: fabric,
                pieces: pieces,
                l: l,
                a: a,
                b: b,
                spread: spread,
                colour: colour,
                photo: photo,
                version: version,
                added: added,
                photoNumber: photoNumber,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int box,
                required String name,
                required String fabric,
                required int pieces,
                required double l,
                required double a,
                required double b,
                required double spread,
                required String colour,
                required Uint8List photo,
                Value<int> version = const Value.absent(),
                required DateTime added,
                Value<int> photoNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClothsCompanion.insert(
                id: id,
                box: box,
                name: name,
                fabric: fabric,
                pieces: pieces,
                l: l,
                a: a,
                b: b,
                spread: spread,
                colour: colour,
                photo: photo,
                version: version,
                added: added,
                photoNumber: photoNumber,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClothsTable, ClothRow>(table),
                  $$ClothsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({box = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (box) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.box,
                        referencedTable: $$ClothsTableReferences._boxTable(db),
                        referencedColumn: $$ClothsTableReferences
                            ._boxTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClothsTableProcessedTableManager =
    ProcessedTableManager<
      _$KanthaDatabase,
      $ClothsTable,
      ClothRow,
      $$ClothsTableFilterComposer,
      $$ClothsTableOrderingComposer,
      $$ClothsTableAnnotationComposer,
      $$ClothsTableCreateCompanionBuilder,
      $$ClothsTableUpdateCompanionBuilder,
      (ClothRow, $$ClothsTableReferences),
      ClothRow,
      PrefetchHooks Function({bool box})
    >;
typedef $$DesignsTableCreateCompanionBuilder = DesignsCompanion Function({
  required String id,
  required String name,
  required String layout,
  required String mount,
  Value<int?> box,
  Value<int?> seed,
  Value<String?> started,
  Value<String?> firstSolve,
  required String grid,
  required DateTime saved,
  Value<int?> cols,
  Value<int> rowid,
});
typedef $$DesignsTableUpdateCompanionBuilder = DesignsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> layout,
  Value<String> mount,
  Value<int?> box,
  Value<int?> seed,
  Value<String?> started,
  Value<String?> firstSolve,
  Value<String> grid,
  Value<DateTime> saved,
  Value<int?> cols,
  Value<int> rowid,
});

class $$DesignsTableFilterComposer
    extends Composer<_$KanthaDatabase, $DesignsTable> {
  $$DesignsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layout => $composableBuilder(
    column: $table.layout,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mount => $composableBuilder(
    column: $table.mount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get started => $composableBuilder(
    column: $table.started,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstSolve => $composableBuilder(
    column: $table.firstSolve,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grid => $composableBuilder(
    column: $table.grid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cols => $composableBuilder(
    column: $table.cols,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DesignsTableOrderingComposer
    extends Composer<_$KanthaDatabase, $DesignsTable> {
  $$DesignsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layout => $composableBuilder(
    column: $table.layout,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mount => $composableBuilder(
    column: $table.mount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get box => $composableBuilder(
    column: $table.box,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get started => $composableBuilder(
    column: $table.started,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstSolve => $composableBuilder(
    column: $table.firstSolve,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grid => $composableBuilder(
    column: $table.grid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cols => $composableBuilder(
    column: $table.cols,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DesignsTableAnnotationComposer
    extends Composer<_$KanthaDatabase, $DesignsTable> {
  $$DesignsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get layout =>
      $composableBuilder(column: $table.layout, builder: (column) => column);

  GeneratedColumn<String> get mount =>
      $composableBuilder(column: $table.mount, builder: (column) => column);

  GeneratedColumn<int> get box =>
      $composableBuilder(column: $table.box, builder: (column) => column);

  GeneratedColumn<int> get seed =>
      $composableBuilder(column: $table.seed, builder: (column) => column);

  GeneratedColumn<String> get started =>
      $composableBuilder(column: $table.started, builder: (column) => column);

  GeneratedColumn<String> get firstSolve => $composableBuilder(
    column: $table.firstSolve,
    builder: (column) => column,
  );

  GeneratedColumn<String> get grid =>
      $composableBuilder(column: $table.grid, builder: (column) => column);

  GeneratedColumn<DateTime> get saved =>
      $composableBuilder(column: $table.saved, builder: (column) => column);

  GeneratedColumn<int> get cols =>
      $composableBuilder(column: $table.cols, builder: (column) => column);
}

class $$DesignsTableTableManager
    extends
        RootTableManager<
          _$KanthaDatabase,
          $DesignsTable,
          DesignRow,
          $$DesignsTableFilterComposer,
          $$DesignsTableOrderingComposer,
          $$DesignsTableAnnotationComposer,
          $$DesignsTableCreateCompanionBuilder,
          $$DesignsTableUpdateCompanionBuilder,
          (
            DesignRow,
            BaseReferences<_$KanthaDatabase, $DesignsTable, DesignRow>,
          ),
          DesignRow,
          PrefetchHooks Function()
        > {
  $$DesignsTableTableManager(_$KanthaDatabase db, $DesignsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DesignsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DesignsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DesignsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> layout = const Value.absent(),
                Value<String> mount = const Value.absent(),
                Value<int?> box = const Value.absent(),
                Value<int?> seed = const Value.absent(),
                Value<String?> started = const Value.absent(),
                Value<String?> firstSolve = const Value.absent(),
                Value<String> grid = const Value.absent(),
                Value<DateTime> saved = const Value.absent(),
                Value<int?> cols = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DesignsCompanion(
                id: id,
                name: name,
                layout: layout,
                mount: mount,
                box: box,
                seed: seed,
                started: started,
                firstSolve: firstSolve,
                grid: grid,
                saved: saved,
                cols: cols,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String layout,
                required String mount,
                Value<int?> box = const Value.absent(),
                Value<int?> seed = const Value.absent(),
                Value<String?> started = const Value.absent(),
                Value<String?> firstSolve = const Value.absent(),
                required String grid,
                required DateTime saved,
                Value<int?> cols = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DesignsCompanion.insert(
                id: id,
                name: name,
                layout: layout,
                mount: mount,
                box: box,
                seed: seed,
                started: started,
                firstSolve: firstSolve,
                grid: grid,
                saved: saved,
                cols: cols,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DesignsTable, DesignRow>(table),
                  BaseReferences<_$KanthaDatabase, $DesignsTable, DesignRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DesignsTableProcessedTableManager =
    ProcessedTableManager<
      _$KanthaDatabase,
      $DesignsTable,
      DesignRow,
      $$DesignsTableFilterComposer,
      $$DesignsTableOrderingComposer,
      $$DesignsTableAnnotationComposer,
      $$DesignsTableCreateCompanionBuilder,
      $$DesignsTableUpdateCompanionBuilder,
      (DesignRow, BaseReferences<_$KanthaDatabase, $DesignsTable, DesignRow>),
      DesignRow,
      PrefetchHooks Function()
    >;
typedef $$PicturesTableCreateCompanionBuilder = PicturesCompanion Function({
  Value<int> id,
  Value<String?> design,
  required String name,
  required DateTime made,
  required DateTime saved,
  required Uint8List png,
  required Uint8List thumb,
});
typedef $$PicturesTableUpdateCompanionBuilder = PicturesCompanion Function({
  Value<int> id,
  Value<String?> design,
  Value<String> name,
  Value<DateTime> made,
  Value<DateTime> saved,
  Value<Uint8List> png,
  Value<Uint8List> thumb,
});

class $$PicturesTableFilterComposer
    extends Composer<_$KanthaDatabase, $PicturesTable> {
  $$PicturesTableFilterComposer({
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

  ColumnFilters<String> get design => $composableBuilder(
    column: $table.design,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get made => $composableBuilder(
    column: $table.made,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get png => $composableBuilder(
    column: $table.png,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get thumb => $composableBuilder(
    column: $table.thumb,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PicturesTableOrderingComposer
    extends Composer<_$KanthaDatabase, $PicturesTable> {
  $$PicturesTableOrderingComposer({
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

  ColumnOrderings<String> get design => $composableBuilder(
    column: $table.design,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get made => $composableBuilder(
    column: $table.made,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get png => $composableBuilder(
    column: $table.png,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get thumb => $composableBuilder(
    column: $table.thumb,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PicturesTableAnnotationComposer
    extends Composer<_$KanthaDatabase, $PicturesTable> {
  $$PicturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get design =>
      $composableBuilder(column: $table.design, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get made =>
      $composableBuilder(column: $table.made, builder: (column) => column);

  GeneratedColumn<DateTime> get saved =>
      $composableBuilder(column: $table.saved, builder: (column) => column);

  GeneratedColumn<Uint8List> get png =>
      $composableBuilder(column: $table.png, builder: (column) => column);

  GeneratedColumn<Uint8List> get thumb =>
      $composableBuilder(column: $table.thumb, builder: (column) => column);
}

class $$PicturesTableTableManager
    extends
        RootTableManager<
          _$KanthaDatabase,
          $PicturesTable,
          PictureRow,
          $$PicturesTableFilterComposer,
          $$PicturesTableOrderingComposer,
          $$PicturesTableAnnotationComposer,
          $$PicturesTableCreateCompanionBuilder,
          $$PicturesTableUpdateCompanionBuilder,
          (
            PictureRow,
            BaseReferences<_$KanthaDatabase, $PicturesTable, PictureRow>,
          ),
          PictureRow,
          PrefetchHooks Function()
        > {
  $$PicturesTableTableManager(_$KanthaDatabase db, $PicturesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PicturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PicturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PicturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> design = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> made = const Value.absent(),
                Value<DateTime> saved = const Value.absent(),
                Value<Uint8List> png = const Value.absent(),
                Value<Uint8List> thumb = const Value.absent(),
              }) => PicturesCompanion(
                id: id,
                design: design,
                name: name,
                made: made,
                saved: saved,
                png: png,
                thumb: thumb,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> design = const Value.absent(),
                required String name,
                required DateTime made,
                required DateTime saved,
                required Uint8List png,
                required Uint8List thumb,
              }) => PicturesCompanion.insert(
                id: id,
                design: design,
                name: name,
                made: made,
                saved: saved,
                png: png,
                thumb: thumb,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PicturesTable, PictureRow>(table),
                  BaseReferences<_$KanthaDatabase, $PicturesTable, PictureRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PicturesTableProcessedTableManager =
    ProcessedTableManager<
      _$KanthaDatabase,
      $PicturesTable,
      PictureRow,
      $$PicturesTableFilterComposer,
      $$PicturesTableOrderingComposer,
      $$PicturesTableAnnotationComposer,
      $$PicturesTableCreateCompanionBuilder,
      $$PicturesTableUpdateCompanionBuilder,
      (
        PictureRow,
        BaseReferences<_$KanthaDatabase, $PicturesTable, PictureRow>,
      ),
      PictureRow,
      PrefetchHooks Function()
    >;
typedef $$CountersTableCreateCompanionBuilder = CountersCompanion Function({
  required String name,
  required int next,
  Value<int> rowid,
});
typedef $$CountersTableUpdateCompanionBuilder = CountersCompanion Function({
  Value<String> name,
  Value<int> next,
  Value<int> rowid,
});

class $$CountersTableFilterComposer
    extends Composer<_$KanthaDatabase, $CountersTable> {
  $$CountersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get next => $composableBuilder(
    column: $table.next,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CountersTableOrderingComposer
    extends Composer<_$KanthaDatabase, $CountersTable> {
  $$CountersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get next => $composableBuilder(
    column: $table.next,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CountersTableAnnotationComposer
    extends Composer<_$KanthaDatabase, $CountersTable> {
  $$CountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get next =>
      $composableBuilder(column: $table.next, builder: (column) => column);
}

class $$CountersTableTableManager
    extends
        RootTableManager<
          _$KanthaDatabase,
          $CountersTable,
          CounterRow,
          $$CountersTableFilterComposer,
          $$CountersTableOrderingComposer,
          $$CountersTableAnnotationComposer,
          $$CountersTableCreateCompanionBuilder,
          $$CountersTableUpdateCompanionBuilder,
          (
            CounterRow,
            BaseReferences<_$KanthaDatabase, $CountersTable, CounterRow>,
          ),
          CounterRow,
          PrefetchHooks Function()
        > {
  $$CountersTableTableManager(_$KanthaDatabase db, $CountersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<int> next = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CountersCompanion(name: name, next: next, rowid: rowid),
          createCompanionCallback: ({
            required String name,
            required int next,
            Value<int> rowid = const Value.absent(),
          }) => CountersCompanion.insert(name: name, next: next, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CountersTable, CounterRow>(table),
                  BaseReferences<_$KanthaDatabase, $CountersTable, CounterRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CountersTableProcessedTableManager =
    ProcessedTableManager<
      _$KanthaDatabase,
      $CountersTable,
      CounterRow,
      $$CountersTableFilterComposer,
      $$CountersTableOrderingComposer,
      $$CountersTableAnnotationComposer,
      $$CountersTableCreateCompanionBuilder,
      $$CountersTableUpdateCompanionBuilder,
      (
        CounterRow,
        BaseReferences<_$KanthaDatabase, $CountersTable, CounterRow>,
      ),
      CounterRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$KanthaDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$KanthaDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$KanthaDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$KanthaDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$KanthaDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$KanthaDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$KanthaDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$KanthaDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$KanthaDatabase, $SettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $KanthaDatabaseManager {
  final _$KanthaDatabase _db;
  $KanthaDatabaseManager(this._db);
  $$BoxesTableTableManager get boxes =>
      $$BoxesTableTableManager(_db, _db.boxes);
  $$ClothsTableTableManager get cloths =>
      $$ClothsTableTableManager(_db, _db.cloths);
  $$DesignsTableTableManager get designs =>
      $$DesignsTableTableManager(_db, _db.designs);
  $$PicturesTableTableManager get pictures =>
      $$PicturesTableTableManager(_db, _db.pictures);
  $$CountersTableTableManager get counters =>
      $$CountersTableTableManager(_db, _db.counters);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
