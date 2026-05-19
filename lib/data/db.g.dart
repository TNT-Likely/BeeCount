// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $LedgersTable extends Ledgers with TableInfo<$LedgersTable, Ledger> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _myRoleMeta = const VerificationMeta('myRole');
  @override
  late final GeneratedColumn<String> myRole = GeneratedColumn<String>(
      'my_role', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('owner'));
  static const VerificationMeta _memberCountMeta =
      const VerificationMeta('memberCount');
  @override
  late final GeneratedColumn<int> memberCount = GeneratedColumn<int>(
      'member_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _isSharedMeta =
      const VerificationMeta('isShared');
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
      'is_shared', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_shared" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _ownerUserIdMeta =
      const VerificationMeta('ownerUserId');
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
      'owner_user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        currency,
        type,
        createdAt,
        syncId,
        myRole,
        memberCount,
        isShared,
        ownerUserId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledgers';
  @override
  VerificationContext validateIntegrity(Insertable<Ledger> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    if (data.containsKey('my_role')) {
      context.handle(_myRoleMeta,
          myRole.isAcceptableOrUnknown(data['my_role']!, _myRoleMeta));
    }
    if (data.containsKey('member_count')) {
      context.handle(
          _memberCountMeta,
          memberCount.isAcceptableOrUnknown(
              data['member_count']!, _memberCountMeta));
    }
    if (data.containsKey('is_shared')) {
      context.handle(_isSharedMeta,
          isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta));
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
          _ownerUserIdMeta,
          ownerUserId.isAcceptableOrUnknown(
              data['owner_user_id']!, _ownerUserIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ledger map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ledger(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
      myRole: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_role'])!,
      memberCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}member_count'])!,
      isShared: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_shared'])!,
      ownerUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_user_id']),
    );
  }

  @override
  $LedgersTable createAlias(String alias) {
    return $LedgersTable(attachedDatabase, alias);
  }
}

class Ledger extends DataClass implements Insertable<Ledger> {
  final int id;
  final String name;
  final String currency;
  final String type;
  final DateTime createdAt;
  final String? syncId;
  final String myRole;
  final int memberCount;
  final bool isShared;
  final String? ownerUserId;
  const Ledger(
      {required this.id,
      required this.name,
      required this.currency,
      required this.type,
      required this.createdAt,
      this.syncId,
      required this.myRole,
      required this.memberCount,
      required this.isShared,
      this.ownerUserId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['type'] = Variable<String>(type);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['my_role'] = Variable<String>(myRole);
    map['member_count'] = Variable<int>(memberCount);
    map['is_shared'] = Variable<bool>(isShared);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    return map;
  }

  LedgersCompanion toCompanion(bool nullToAbsent) {
    return LedgersCompanion(
      id: Value(id),
      name: Value(name),
      currency: Value(currency),
      type: Value(type),
      createdAt: Value(createdAt),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
      myRole: Value(myRole),
      memberCount: Value(memberCount),
      isShared: Value(isShared),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
    );
  }

  factory Ledger.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ledger(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      myRole: serializer.fromJson<String>(json['myRole']),
      memberCount: serializer.fromJson<int>(json['memberCount']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncId': serializer.toJson<String?>(syncId),
      'myRole': serializer.toJson<String>(myRole),
      'memberCount': serializer.toJson<int>(memberCount),
      'isShared': serializer.toJson<bool>(isShared),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
    };
  }

  Ledger copyWith(
          {int? id,
          String? name,
          String? currency,
          String? type,
          DateTime? createdAt,
          Value<String?> syncId = const Value.absent(),
          String? myRole,
          int? memberCount,
          bool? isShared,
          Value<String?> ownerUserId = const Value.absent()}) =>
      Ledger(
        id: id ?? this.id,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        syncId: syncId.present ? syncId.value : this.syncId,
        myRole: myRole ?? this.myRole,
        memberCount: memberCount ?? this.memberCount,
        isShared: isShared ?? this.isShared,
        ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
      );
  Ledger copyWithCompanion(LedgersCompanion data) {
    return Ledger(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      myRole: data.myRole.present ? data.myRole.value : this.myRole,
      memberCount:
          data.memberCount.present ? data.memberCount.value : this.memberCount,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      ownerUserId:
          data.ownerUserId.present ? data.ownerUserId.value : this.ownerUserId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ledger(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId, ')
          ..write('myRole: $myRole, ')
          ..write('memberCount: $memberCount, ')
          ..write('isShared: $isShared, ')
          ..write('ownerUserId: $ownerUserId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, currency, type, createdAt, syncId,
      myRole, memberCount, isShared, ownerUserId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ledger &&
          other.id == this.id &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.syncId == this.syncId &&
          other.myRole == this.myRole &&
          other.memberCount == this.memberCount &&
          other.isShared == this.isShared &&
          other.ownerUserId == this.ownerUserId);
}

class LedgersCompanion extends UpdateCompanion<Ledger> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> currency;
  final Value<String> type;
  final Value<DateTime> createdAt;
  final Value<String?> syncId;
  final Value<String> myRole;
  final Value<int> memberCount;
  final Value<bool> isShared;
  final Value<String?> ownerUserId;
  const LedgersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.myRole = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.isShared = const Value.absent(),
    this.ownerUserId = const Value.absent(),
  });
  LedgersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.currency = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.myRole = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.isShared = const Value.absent(),
    this.ownerUserId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Ledger> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
    Expression<String>? syncId,
    Expression<String>? myRole,
    Expression<int>? memberCount,
    Expression<bool>? isShared,
    Expression<String>? ownerUserId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (syncId != null) 'sync_id': syncId,
      if (myRole != null) 'my_role': myRole,
      if (memberCount != null) 'member_count': memberCount,
      if (isShared != null) 'is_shared': isShared,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
    });
  }

  LedgersCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? currency,
      Value<String>? type,
      Value<DateTime>? createdAt,
      Value<String?>? syncId,
      Value<String>? myRole,
      Value<int>? memberCount,
      Value<bool>? isShared,
      Value<String?>? ownerUserId}) {
    return LedgersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      syncId: syncId ?? this.syncId,
      myRole: myRole ?? this.myRole,
      memberCount: memberCount ?? this.memberCount,
      isShared: isShared ?? this.isShared,
      ownerUserId: ownerUserId ?? this.ownerUserId,
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
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (myRole.present) {
      map['my_role'] = Variable<String>(myRole.value);
    }
    if (memberCount.present) {
      map['member_count'] = Variable<int>(memberCount.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId, ')
          ..write('myRole: $myRole, ')
          ..write('memberCount: $memberCount, ')
          ..write('isShared: $isShared, ')
          ..write('ownerUserId: $ownerUserId')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('cash'));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _initialBalanceMeta =
      const VerificationMeta('initialBalance');
  @override
  late final GeneratedColumn<double> initialBalance = GeneratedColumn<double>(
      'initial_balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _creditLimitMeta =
      const VerificationMeta('creditLimit');
  @override
  late final GeneratedColumn<double> creditLimit = GeneratedColumn<double>(
      'credit_limit', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _billingDayMeta =
      const VerificationMeta('billingDay');
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
      'billing_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _paymentDueDayMeta =
      const VerificationMeta('paymentDueDay');
  @override
  late final GeneratedColumn<int> paymentDueDay = GeneratedColumn<int>(
      'payment_due_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bankNameMeta =
      const VerificationMeta('bankName');
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
      'bank_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cardLastFourMeta =
      const VerificationMeta('cardLastFour');
  @override
  late final GeneratedColumn<String> cardLastFour = GeneratedColumn<String>(
      'card_last_four', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ledgerId,
        name,
        type,
        currency,
        initialBalance,
        createdAt,
        updatedAt,
        sortOrder,
        creditLimit,
        billingDay,
        paymentDueDay,
        bankName,
        cardLastFour,
        note,
        syncId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
          _initialBalanceMeta,
          initialBalance.isAcceptableOrUnknown(
              data['initial_balance']!, _initialBalanceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('credit_limit')) {
      context.handle(
          _creditLimitMeta,
          creditLimit.isAcceptableOrUnknown(
              data['credit_limit']!, _creditLimitMeta));
    }
    if (data.containsKey('billing_day')) {
      context.handle(
          _billingDayMeta,
          billingDay.isAcceptableOrUnknown(
              data['billing_day']!, _billingDayMeta));
    }
    if (data.containsKey('payment_due_day')) {
      context.handle(
          _paymentDueDayMeta,
          paymentDueDay.isAcceptableOrUnknown(
              data['payment_due_day']!, _paymentDueDayMeta));
    }
    if (data.containsKey('bank_name')) {
      context.handle(_bankNameMeta,
          bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta));
    }
    if (data.containsKey('card_last_four')) {
      context.handle(
          _cardLastFourMeta,
          cardLastFour.isAcceptableOrUnknown(
              data['card_last_four']!, _cardLastFourMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      initialBalance: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}initial_balance'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      creditLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}credit_limit']),
      billingDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}billing_day']),
      paymentDueDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment_due_day']),
      bankName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bank_name']),
      cardLastFour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_last_four']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final int ledgerId;
  final String name;
  final String type;
  final String currency;
  final double initialBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int sortOrder;
  final double? creditLimit;
  final int? billingDay;
  final int? paymentDueDay;
  final String? bankName;
  final String? cardLastFour;
  final String? note;
  final String? syncId;
  const Account(
      {required this.id,
      required this.ledgerId,
      required this.name,
      required this.type,
      required this.currency,
      required this.initialBalance,
      this.createdAt,
      this.updatedAt,
      required this.sortOrder,
      this.creditLimit,
      this.billingDay,
      this.paymentDueDay,
      this.bankName,
      this.cardLastFour,
      this.note,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['currency'] = Variable<String>(currency);
    map['initial_balance'] = Variable<double>(initialBalance);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || creditLimit != null) {
      map['credit_limit'] = Variable<double>(creditLimit);
    }
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || paymentDueDay != null) {
      map['payment_due_day'] = Variable<int>(paymentDueDay);
    }
    if (!nullToAbsent || bankName != null) {
      map['bank_name'] = Variable<String>(bankName);
    }
    if (!nullToAbsent || cardLastFour != null) {
      map['card_last_four'] = Variable<String>(cardLastFour);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      name: Value(name),
      type: Value(type),
      currency: Value(currency),
      initialBalance: Value(initialBalance),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      sortOrder: Value(sortOrder),
      creditLimit: creditLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimit),
      billingDay: billingDay == null && nullToAbsent
          ? const Value.absent()
          : Value(billingDay),
      paymentDueDay: paymentDueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentDueDay),
      bankName: bankName == null && nullToAbsent
          ? const Value.absent()
          : Value(bankName),
      cardLastFour: cardLastFour == null && nullToAbsent
          ? const Value.absent()
          : Value(cardLastFour),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      currency: serializer.fromJson<String>(json['currency']),
      initialBalance: serializer.fromJson<double>(json['initialBalance']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      creditLimit: serializer.fromJson<double?>(json['creditLimit']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      paymentDueDay: serializer.fromJson<int?>(json['paymentDueDay']),
      bankName: serializer.fromJson<String?>(json['bankName']),
      cardLastFour: serializer.fromJson<String?>(json['cardLastFour']),
      note: serializer.fromJson<String?>(json['note']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'currency': serializer.toJson<String>(currency),
      'initialBalance': serializer.toJson<double>(initialBalance),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'creditLimit': serializer.toJson<double?>(creditLimit),
      'billingDay': serializer.toJson<int?>(billingDay),
      'paymentDueDay': serializer.toJson<int?>(paymentDueDay),
      'bankName': serializer.toJson<String?>(bankName),
      'cardLastFour': serializer.toJson<String?>(cardLastFour),
      'note': serializer.toJson<String?>(note),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Account copyWith(
          {int? id,
          int? ledgerId,
          String? name,
          String? type,
          String? currency,
          double? initialBalance,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          int? sortOrder,
          Value<double?> creditLimit = const Value.absent(),
          Value<int?> billingDay = const Value.absent(),
          Value<int?> paymentDueDay = const Value.absent(),
          Value<String?> bankName = const Value.absent(),
          Value<String?> cardLastFour = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<String?> syncId = const Value.absent()}) =>
      Account(
        id: id ?? this.id,
        ledgerId: ledgerId ?? this.ledgerId,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        initialBalance: initialBalance ?? this.initialBalance,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        sortOrder: sortOrder ?? this.sortOrder,
        creditLimit: creditLimit.present ? creditLimit.value : this.creditLimit,
        billingDay: billingDay.present ? billingDay.value : this.billingDay,
        paymentDueDay:
            paymentDueDay.present ? paymentDueDay.value : this.paymentDueDay,
        bankName: bankName.present ? bankName.value : this.bankName,
        cardLastFour:
            cardLastFour.present ? cardLastFour.value : this.cardLastFour,
        note: note.present ? note.value : this.note,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      initialBalance: data.initialBalance.present
          ? data.initialBalance.value
          : this.initialBalance,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      creditLimit:
          data.creditLimit.present ? data.creditLimit.value : this.creditLimit,
      billingDay:
          data.billingDay.present ? data.billingDay.value : this.billingDay,
      paymentDueDay: data.paymentDueDay.present
          ? data.paymentDueDay.value
          : this.paymentDueDay,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      cardLastFour: data.cardLastFour.present
          ? data.cardLastFour.value
          : this.cardLastFour,
      note: data.note.present ? data.note.value : this.note,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('bankName: $bankName, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('note: $note, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ledgerId,
      name,
      type,
      currency,
      initialBalance,
      createdAt,
      updatedAt,
      sortOrder,
      creditLimit,
      billingDay,
      paymentDueDay,
      bankName,
      cardLastFour,
      note,
      syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.name == this.name &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.initialBalance == this.initialBalance &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sortOrder == this.sortOrder &&
          other.creditLimit == this.creditLimit &&
          other.billingDay == this.billingDay &&
          other.paymentDueDay == this.paymentDueDay &&
          other.bankName == this.bankName &&
          other.cardLastFour == this.cardLastFour &&
          other.note == this.note &&
          other.syncId == this.syncId);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> currency;
  final Value<double> initialBalance;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> sortOrder;
  final Value<double?> creditLimit;
  final Value<int?> billingDay;
  final Value<int?> paymentDueDay;
  final Value<String?> bankName;
  final Value<String?> cardLastFour;
  final Value<String?> note;
  final Value<String?> syncId;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.bankName = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    this.note = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String name,
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.bankName = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    this.note = const Value.absent(),
    this.syncId = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        name = Value(name);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<double>? initialBalance,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? sortOrder,
    Expression<double>? creditLimit,
    Expression<int>? billingDay,
    Expression<int>? paymentDueDay,
    Expression<String>? bankName,
    Expression<String>? cardLastFour,
    Expression<String>? note,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (billingDay != null) 'billing_day': billingDay,
      if (paymentDueDay != null) 'payment_due_day': paymentDueDay,
      if (bankName != null) 'bank_name': bankName,
      if (cardLastFour != null) 'card_last_four': cardLastFour,
      if (note != null) 'note': note,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  AccountsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ledgerId,
      Value<String>? name,
      Value<String>? type,
      Value<String>? currency,
      Value<double>? initialBalance,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? sortOrder,
      Value<double?>? creditLimit,
      Value<int?>? billingDay,
      Value<int?>? paymentDueDay,
      Value<String?>? bankName,
      Value<String?>? cardLastFour,
      Value<String?>? note,
      Value<String?>? syncId}) {
    return AccountsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? this.initialBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      creditLimit: creditLimit ?? this.creditLimit,
      billingDay: billingDay ?? this.billingDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      bankName: bankName ?? this.bankName,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      note: note ?? this.note,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<double>(initialBalance.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (creditLimit.present) {
      map['credit_limit'] = Variable<double>(creditLimit.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (paymentDueDay.present) {
      map['payment_due_day'] = Variable<int>(paymentDueDay.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (cardLastFour.present) {
      map['card_last_four'] = Variable<String>(cardLastFour.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('bankName: $bankName, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('note: $note, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
      'level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _iconTypeMeta =
      const VerificationMeta('iconType');
  @override
  late final GeneratedColumn<String> iconType = GeneratedColumn<String>(
      'icon_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('material'));
  static const VerificationMeta _customIconPathMeta =
      const VerificationMeta('customIconPath');
  @override
  late final GeneratedColumn<String> customIconPath = GeneratedColumn<String>(
      'custom_icon_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _communityIconIdMeta =
      const VerificationMeta('communityIconId');
  @override
  late final GeneratedColumn<String> communityIconId = GeneratedColumn<String>(
      'community_icon_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        kind,
        icon,
        sortOrder,
        parentId,
        level,
        iconType,
        customIconPath,
        communityIconId,
        syncId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('icon_type')) {
      context.handle(_iconTypeMeta,
          iconType.isAcceptableOrUnknown(data['icon_type']!, _iconTypeMeta));
    }
    if (data.containsKey('custom_icon_path')) {
      context.handle(
          _customIconPathMeta,
          customIconPath.isAcceptableOrUnknown(
              data['custom_icon_path']!, _customIconPathMeta));
    }
    if (data.containsKey('community_icon_id')) {
      context.handle(
          _communityIconIdMeta,
          communityIconId.isAcceptableOrUnknown(
              data['community_icon_id']!, _communityIconIdMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_id']),
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level'])!,
      iconType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_type'])!,
      customIconPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}custom_icon_path']),
      communityIconId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}community_icon_id']),
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final String kind;
  final String? icon;
  final int sortOrder;
  final int? parentId;
  final int level;
  final String iconType;
  final String? customIconPath;
  final String? communityIconId;
  final String? syncId;
  const Category(
      {required this.id,
      required this.name,
      required this.kind,
      this.icon,
      required this.sortOrder,
      this.parentId,
      required this.level,
      required this.iconType,
      this.customIconPath,
      this.communityIconId,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['level'] = Variable<int>(level);
    map['icon_type'] = Variable<String>(iconType);
    if (!nullToAbsent || customIconPath != null) {
      map['custom_icon_path'] = Variable<String>(customIconPath);
    }
    if (!nullToAbsent || communityIconId != null) {
      map['community_icon_id'] = Variable<String>(communityIconId);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      level: Value(level),
      iconType: Value(iconType),
      customIconPath: customIconPath == null && nullToAbsent
          ? const Value.absent()
          : Value(customIconPath),
      communityIconId: communityIconId == null && nullToAbsent
          ? const Value.absent()
          : Value(communityIconId),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      level: serializer.fromJson<int>(json['level']),
      iconType: serializer.fromJson<String>(json['iconType']),
      customIconPath: serializer.fromJson<String?>(json['customIconPath']),
      communityIconId: serializer.fromJson<String?>(json['communityIconId']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'parentId': serializer.toJson<int?>(parentId),
      'level': serializer.toJson<int>(level),
      'iconType': serializer.toJson<String>(iconType),
      'customIconPath': serializer.toJson<String?>(customIconPath),
      'communityIconId': serializer.toJson<String?>(communityIconId),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Category copyWith(
          {int? id,
          String? name,
          String? kind,
          Value<String?> icon = const Value.absent(),
          int? sortOrder,
          Value<int?> parentId = const Value.absent(),
          int? level,
          String? iconType,
          Value<String?> customIconPath = const Value.absent(),
          Value<String?> communityIconId = const Value.absent(),
          Value<String?> syncId = const Value.absent()}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        icon: icon.present ? icon.value : this.icon,
        sortOrder: sortOrder ?? this.sortOrder,
        parentId: parentId.present ? parentId.value : this.parentId,
        level: level ?? this.level,
        iconType: iconType ?? this.iconType,
        customIconPath:
            customIconPath.present ? customIconPath.value : this.customIconPath,
        communityIconId: communityIconId.present
            ? communityIconId.value
            : this.communityIconId,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      level: data.level.present ? data.level.value : this.level,
      iconType: data.iconType.present ? data.iconType.value : this.iconType,
      customIconPath: data.customIconPath.present
          ? data.customIconPath.value
          : this.customIconPath,
      communityIconId: data.communityIconId.present
          ? data.communityIconId.value
          : this.communityIconId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('iconType: $iconType, ')
          ..write('customIconPath: $customIconPath, ')
          ..write('communityIconId: $communityIconId, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, kind, icon, sortOrder, parentId,
      level, iconType, customIconPath, communityIconId, syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.parentId == this.parentId &&
          other.level == this.level &&
          other.iconType == this.iconType &&
          other.customIconPath == this.customIconPath &&
          other.communityIconId == this.communityIconId &&
          other.syncId == this.syncId);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> icon;
  final Value<int> sortOrder;
  final Value<int?> parentId;
  final Value<int> level;
  final Value<String> iconType;
  final Value<String?> customIconPath;
  final Value<String?> communityIconId;
  final Value<String?> syncId;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    this.iconType = const Value.absent(),
    this.customIconPath = const Value.absent(),
    this.communityIconId = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String kind,
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    this.iconType = const Value.absent(),
    this.customIconPath = const Value.absent(),
    this.communityIconId = const Value.absent(),
    this.syncId = const Value.absent(),
  })  : name = Value(name),
        kind = Value(kind);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<int>? parentId,
    Expression<int>? level,
    Expression<String>? iconType,
    Expression<String>? customIconPath,
    Expression<String>? communityIconId,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (parentId != null) 'parent_id': parentId,
      if (level != null) 'level': level,
      if (iconType != null) 'icon_type': iconType,
      if (customIconPath != null) 'custom_icon_path': customIconPath,
      if (communityIconId != null) 'community_icon_id': communityIconId,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  CategoriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? kind,
      Value<String?>? icon,
      Value<int>? sortOrder,
      Value<int?>? parentId,
      Value<int>? level,
      Value<String>? iconType,
      Value<String?>? customIconPath,
      Value<String?>? communityIconId,
      Value<String?>? syncId}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      iconType: iconType ?? this.iconType,
      customIconPath: customIconPath ?? this.customIconPath,
      communityIconId: communityIconId ?? this.communityIconId,
      syncId: syncId ?? this.syncId,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (iconType.present) {
      map['icon_type'] = Variable<String>(iconType.value);
    }
    if (customIconPath.present) {
      map['custom_icon_path'] = Variable<String>(customIconPath.value);
    }
    if (communityIconId.present) {
      map['community_icon_id'] = Variable<String>(communityIconId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('iconType: $iconType, ')
          ..write('customIconPath: $customIconPath, ')
          ..write('communityIconId: $communityIconId, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _toAccountIdMeta =
      const VerificationMeta('toAccountId');
  @override
  late final GeneratedColumn<int> toAccountId = GeneratedColumn<int>(
      'to_account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _happenedAtMeta =
      const VerificationMeta('happenedAt');
  @override
  late final GeneratedColumn<DateTime> happenedAt = GeneratedColumn<DateTime>(
      'happened_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recurringIdMeta =
      const VerificationMeta('recurringId');
  @override
  late final GeneratedColumn<int> recurringId = GeneratedColumn<int>(
      'recurring_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByUserIdMeta =
      const VerificationMeta('createdByUserId');
  @override
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
      'created_by_user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastEditedByUserIdMeta =
      const VerificationMeta('lastEditedByUserId');
  @override
  late final GeneratedColumn<String> lastEditedByUserId =
      GeneratedColumn<String>('last_edited_by_user_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categorySyncIdOverrideMeta =
      const VerificationMeta('categorySyncIdOverride');
  @override
  late final GeneratedColumn<String> categorySyncIdOverride =
      GeneratedColumn<String>('category_sync_id_override', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _accountSyncIdOverrideMeta =
      const VerificationMeta('accountSyncIdOverride');
  @override
  late final GeneratedColumn<String> accountSyncIdOverride =
      GeneratedColumn<String>('account_sync_id_override', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _toAccountSyncIdOverrideMeta =
      const VerificationMeta('toAccountSyncIdOverride');
  @override
  late final GeneratedColumn<String> toAccountSyncIdOverride =
      GeneratedColumn<String>('to_account_sync_id_override', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagSyncIdsOverrideMeta =
      const VerificationMeta('tagSyncIdsOverride');
  @override
  late final GeneratedColumn<String> tagSyncIdsOverride =
      GeneratedColumn<String>('tag_sync_ids_override', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ledgerId,
        type,
        amount,
        categoryId,
        accountId,
        toAccountId,
        happenedAt,
        note,
        recurringId,
        syncId,
        createdByUserId,
        lastEditedByUserId,
        categorySyncIdOverride,
        accountSyncIdOverride,
        toAccountSyncIdOverride,
        tagSyncIdsOverride
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
          _toAccountIdMeta,
          toAccountId.isAcceptableOrUnknown(
              data['to_account_id']!, _toAccountIdMeta));
    }
    if (data.containsKey('happened_at')) {
      context.handle(
          _happenedAtMeta,
          happenedAt.isAcceptableOrUnknown(
              data['happened_at']!, _happenedAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('recurring_id')) {
      context.handle(
          _recurringIdMeta,
          recurringId.isAcceptableOrUnknown(
              data['recurring_id']!, _recurringIdMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
          _createdByUserIdMeta,
          createdByUserId.isAcceptableOrUnknown(
              data['created_by_user_id']!, _createdByUserIdMeta));
    }
    if (data.containsKey('last_edited_by_user_id')) {
      context.handle(
          _lastEditedByUserIdMeta,
          lastEditedByUserId.isAcceptableOrUnknown(
              data['last_edited_by_user_id']!, _lastEditedByUserIdMeta));
    }
    if (data.containsKey('category_sync_id_override')) {
      context.handle(
          _categorySyncIdOverrideMeta,
          categorySyncIdOverride.isAcceptableOrUnknown(
              data['category_sync_id_override']!, _categorySyncIdOverrideMeta));
    }
    if (data.containsKey('account_sync_id_override')) {
      context.handle(
          _accountSyncIdOverrideMeta,
          accountSyncIdOverride.isAcceptableOrUnknown(
              data['account_sync_id_override']!, _accountSyncIdOverrideMeta));
    }
    if (data.containsKey('to_account_sync_id_override')) {
      context.handle(
          _toAccountSyncIdOverrideMeta,
          toAccountSyncIdOverride.isAcceptableOrUnknown(
              data['to_account_sync_id_override']!,
              _toAccountSyncIdOverrideMeta));
    }
    if (data.containsKey('tag_sync_ids_override')) {
      context.handle(
          _tagSyncIdsOverrideMeta,
          tagSyncIdsOverride.isAcceptableOrUnknown(
              data['tag_sync_ids_override']!, _tagSyncIdsOverrideMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id']),
      toAccountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}to_account_id']),
      happenedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}happened_at'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      recurringId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}recurring_id']),
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
      createdByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_by_user_id']),
      lastEditedByUserId: attachedDatabase.typeMapping.read(DriftSqlType.string,
          data['${effectivePrefix}last_edited_by_user_id']),
      categorySyncIdOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category_sync_id_override']),
      accountSyncIdOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}account_sync_id_override']),
      toAccountSyncIdOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}to_account_sync_id_override']),
      tagSyncIdsOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}tag_sync_ids_override']),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;
  final int ledgerId;
  final String type;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final DateTime happenedAt;
  final String? note;
  final int? recurringId;
  final String? syncId;
  final String? createdByUserId;
  final String? lastEditedByUserId;
  final String? categorySyncIdOverride;
  final String? accountSyncIdOverride;
  final String? toAccountSyncIdOverride;
  final String? tagSyncIdsOverride;
  const Transaction(
      {required this.id,
      required this.ledgerId,
      required this.type,
      required this.amount,
      this.categoryId,
      this.accountId,
      this.toAccountId,
      required this.happenedAt,
      this.note,
      this.recurringId,
      this.syncId,
      this.createdByUserId,
      this.lastEditedByUserId,
      this.categorySyncIdOverride,
      this.accountSyncIdOverride,
      this.toAccountSyncIdOverride,
      this.tagSyncIdsOverride});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<int>(toAccountId);
    }
    map['happened_at'] = Variable<DateTime>(happenedAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || recurringId != null) {
      map['recurring_id'] = Variable<int>(recurringId);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    if (!nullToAbsent || createdByUserId != null) {
      map['created_by_user_id'] = Variable<String>(createdByUserId);
    }
    if (!nullToAbsent || lastEditedByUserId != null) {
      map['last_edited_by_user_id'] = Variable<String>(lastEditedByUserId);
    }
    if (!nullToAbsent || categorySyncIdOverride != null) {
      map['category_sync_id_override'] =
          Variable<String>(categorySyncIdOverride);
    }
    if (!nullToAbsent || accountSyncIdOverride != null) {
      map['account_sync_id_override'] = Variable<String>(accountSyncIdOverride);
    }
    if (!nullToAbsent || toAccountSyncIdOverride != null) {
      map['to_account_sync_id_override'] =
          Variable<String>(toAccountSyncIdOverride);
    }
    if (!nullToAbsent || tagSyncIdsOverride != null) {
      map['tag_sync_ids_override'] = Variable<String>(tagSyncIdsOverride);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      type: Value(type),
      amount: Value(amount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      happenedAt: Value(happenedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recurringId: recurringId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurringId),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
      createdByUserId: createdByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByUserId),
      lastEditedByUserId: lastEditedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEditedByUserId),
      categorySyncIdOverride: categorySyncIdOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(categorySyncIdOverride),
      accountSyncIdOverride: accountSyncIdOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(accountSyncIdOverride),
      toAccountSyncIdOverride: toAccountSyncIdOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountSyncIdOverride),
      tagSyncIdsOverride: tagSyncIdsOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(tagSyncIdsOverride),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      toAccountId: serializer.fromJson<int?>(json['toAccountId']),
      happenedAt: serializer.fromJson<DateTime>(json['happenedAt']),
      note: serializer.fromJson<String?>(json['note']),
      recurringId: serializer.fromJson<int?>(json['recurringId']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      createdByUserId: serializer.fromJson<String?>(json['createdByUserId']),
      lastEditedByUserId:
          serializer.fromJson<String?>(json['lastEditedByUserId']),
      categorySyncIdOverride:
          serializer.fromJson<String?>(json['categorySyncIdOverride']),
      accountSyncIdOverride:
          serializer.fromJson<String?>(json['accountSyncIdOverride']),
      toAccountSyncIdOverride:
          serializer.fromJson<String?>(json['toAccountSyncIdOverride']),
      tagSyncIdsOverride:
          serializer.fromJson<String?>(json['tagSyncIdsOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'categoryId': serializer.toJson<int?>(categoryId),
      'accountId': serializer.toJson<int?>(accountId),
      'toAccountId': serializer.toJson<int?>(toAccountId),
      'happenedAt': serializer.toJson<DateTime>(happenedAt),
      'note': serializer.toJson<String?>(note),
      'recurringId': serializer.toJson<int?>(recurringId),
      'syncId': serializer.toJson<String?>(syncId),
      'createdByUserId': serializer.toJson<String?>(createdByUserId),
      'lastEditedByUserId': serializer.toJson<String?>(lastEditedByUserId),
      'categorySyncIdOverride':
          serializer.toJson<String?>(categorySyncIdOverride),
      'accountSyncIdOverride':
          serializer.toJson<String?>(accountSyncIdOverride),
      'toAccountSyncIdOverride':
          serializer.toJson<String?>(toAccountSyncIdOverride),
      'tagSyncIdsOverride': serializer.toJson<String?>(tagSyncIdsOverride),
    };
  }

  Transaction copyWith(
          {int? id,
          int? ledgerId,
          String? type,
          double? amount,
          Value<int?> categoryId = const Value.absent(),
          Value<int?> accountId = const Value.absent(),
          Value<int?> toAccountId = const Value.absent(),
          DateTime? happenedAt,
          Value<String?> note = const Value.absent(),
          Value<int?> recurringId = const Value.absent(),
          Value<String?> syncId = const Value.absent(),
          Value<String?> createdByUserId = const Value.absent(),
          Value<String?> lastEditedByUserId = const Value.absent(),
          Value<String?> categorySyncIdOverride = const Value.absent(),
          Value<String?> accountSyncIdOverride = const Value.absent(),
          Value<String?> toAccountSyncIdOverride = const Value.absent(),
          Value<String?> tagSyncIdsOverride = const Value.absent()}) =>
      Transaction(
        id: id ?? this.id,
        ledgerId: ledgerId ?? this.ledgerId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        accountId: accountId.present ? accountId.value : this.accountId,
        toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
        happenedAt: happenedAt ?? this.happenedAt,
        note: note.present ? note.value : this.note,
        recurringId: recurringId.present ? recurringId.value : this.recurringId,
        syncId: syncId.present ? syncId.value : this.syncId,
        createdByUserId: createdByUserId.present
            ? createdByUserId.value
            : this.createdByUserId,
        lastEditedByUserId: lastEditedByUserId.present
            ? lastEditedByUserId.value
            : this.lastEditedByUserId,
        categorySyncIdOverride: categorySyncIdOverride.present
            ? categorySyncIdOverride.value
            : this.categorySyncIdOverride,
        accountSyncIdOverride: accountSyncIdOverride.present
            ? accountSyncIdOverride.value
            : this.accountSyncIdOverride,
        toAccountSyncIdOverride: toAccountSyncIdOverride.present
            ? toAccountSyncIdOverride.value
            : this.toAccountSyncIdOverride,
        tagSyncIdsOverride: tagSyncIdsOverride.present
            ? tagSyncIdsOverride.value
            : this.tagSyncIdsOverride,
      );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId:
          data.toAccountId.present ? data.toAccountId.value : this.toAccountId,
      happenedAt:
          data.happenedAt.present ? data.happenedAt.value : this.happenedAt,
      note: data.note.present ? data.note.value : this.note,
      recurringId:
          data.recurringId.present ? data.recurringId.value : this.recurringId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      lastEditedByUserId: data.lastEditedByUserId.present
          ? data.lastEditedByUserId.value
          : this.lastEditedByUserId,
      categorySyncIdOverride: data.categorySyncIdOverride.present
          ? data.categorySyncIdOverride.value
          : this.categorySyncIdOverride,
      accountSyncIdOverride: data.accountSyncIdOverride.present
          ? data.accountSyncIdOverride.value
          : this.accountSyncIdOverride,
      toAccountSyncIdOverride: data.toAccountSyncIdOverride.present
          ? data.toAccountSyncIdOverride.value
          : this.toAccountSyncIdOverride,
      tagSyncIdsOverride: data.tagSyncIdsOverride.present
          ? data.tagSyncIdsOverride.value
          : this.tagSyncIdsOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('note: $note, ')
          ..write('recurringId: $recurringId, ')
          ..write('syncId: $syncId, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('lastEditedByUserId: $lastEditedByUserId, ')
          ..write('categorySyncIdOverride: $categorySyncIdOverride, ')
          ..write('accountSyncIdOverride: $accountSyncIdOverride, ')
          ..write('toAccountSyncIdOverride: $toAccountSyncIdOverride, ')
          ..write('tagSyncIdsOverride: $tagSyncIdsOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ledgerId,
      type,
      amount,
      categoryId,
      accountId,
      toAccountId,
      happenedAt,
      note,
      recurringId,
      syncId,
      createdByUserId,
      lastEditedByUserId,
      categorySyncIdOverride,
      accountSyncIdOverride,
      toAccountSyncIdOverride,
      tagSyncIdsOverride);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.happenedAt == this.happenedAt &&
          other.note == this.note &&
          other.recurringId == this.recurringId &&
          other.syncId == this.syncId &&
          other.createdByUserId == this.createdByUserId &&
          other.lastEditedByUserId == this.lastEditedByUserId &&
          other.categorySyncIdOverride == this.categorySyncIdOverride &&
          other.accountSyncIdOverride == this.accountSyncIdOverride &&
          other.toAccountSyncIdOverride == this.toAccountSyncIdOverride &&
          other.tagSyncIdsOverride == this.tagSyncIdsOverride);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<double> amount;
  final Value<int?> categoryId;
  final Value<int?> accountId;
  final Value<int?> toAccountId;
  final Value<DateTime> happenedAt;
  final Value<String?> note;
  final Value<int?> recurringId;
  final Value<String?> syncId;
  final Value<String?> createdByUserId;
  final Value<String?> lastEditedByUserId;
  final Value<String?> categorySyncIdOverride;
  final Value<String?> accountSyncIdOverride;
  final Value<String?> toAccountSyncIdOverride;
  final Value<String?> tagSyncIdsOverride;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.lastEditedByUserId = const Value.absent(),
    this.categorySyncIdOverride = const Value.absent(),
    this.accountSyncIdOverride = const Value.absent(),
    this.toAccountSyncIdOverride = const Value.absent(),
    this.tagSyncIdsOverride = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String type,
    required double amount,
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.lastEditedByUserId = const Value.absent(),
    this.categorySyncIdOverride = const Value.absent(),
    this.accountSyncIdOverride = const Value.absent(),
    this.toAccountSyncIdOverride = const Value.absent(),
    this.tagSyncIdsOverride = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        type = Value(type),
        amount = Value(amount);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<int>? categoryId,
    Expression<int>? accountId,
    Expression<int>? toAccountId,
    Expression<DateTime>? happenedAt,
    Expression<String>? note,
    Expression<int>? recurringId,
    Expression<String>? syncId,
    Expression<String>? createdByUserId,
    Expression<String>? lastEditedByUserId,
    Expression<String>? categorySyncIdOverride,
    Expression<String>? accountSyncIdOverride,
    Expression<String>? toAccountSyncIdOverride,
    Expression<String>? tagSyncIdsOverride,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (happenedAt != null) 'happened_at': happenedAt,
      if (note != null) 'note': note,
      if (recurringId != null) 'recurring_id': recurringId,
      if (syncId != null) 'sync_id': syncId,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (lastEditedByUserId != null)
        'last_edited_by_user_id': lastEditedByUserId,
      if (categorySyncIdOverride != null)
        'category_sync_id_override': categorySyncIdOverride,
      if (accountSyncIdOverride != null)
        'account_sync_id_override': accountSyncIdOverride,
      if (toAccountSyncIdOverride != null)
        'to_account_sync_id_override': toAccountSyncIdOverride,
      if (tagSyncIdsOverride != null)
        'tag_sync_ids_override': tagSyncIdsOverride,
    });
  }

  TransactionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ledgerId,
      Value<String>? type,
      Value<double>? amount,
      Value<int?>? categoryId,
      Value<int?>? accountId,
      Value<int?>? toAccountId,
      Value<DateTime>? happenedAt,
      Value<String?>? note,
      Value<int?>? recurringId,
      Value<String?>? syncId,
      Value<String?>? createdByUserId,
      Value<String?>? lastEditedByUserId,
      Value<String?>? categorySyncIdOverride,
      Value<String?>? accountSyncIdOverride,
      Value<String?>? toAccountSyncIdOverride,
      Value<String?>? tagSyncIdsOverride}) {
    return TransactionsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      happenedAt: happenedAt ?? this.happenedAt,
      note: note ?? this.note,
      recurringId: recurringId ?? this.recurringId,
      syncId: syncId ?? this.syncId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      lastEditedByUserId: lastEditedByUserId ?? this.lastEditedByUserId,
      categorySyncIdOverride:
          categorySyncIdOverride ?? this.categorySyncIdOverride,
      accountSyncIdOverride:
          accountSyncIdOverride ?? this.accountSyncIdOverride,
      toAccountSyncIdOverride:
          toAccountSyncIdOverride ?? this.toAccountSyncIdOverride,
      tagSyncIdsOverride: tagSyncIdsOverride ?? this.tagSyncIdsOverride,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<int>(toAccountId.value);
    }
    if (happenedAt.present) {
      map['happened_at'] = Variable<DateTime>(happenedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recurringId.present) {
      map['recurring_id'] = Variable<int>(recurringId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (lastEditedByUserId.present) {
      map['last_edited_by_user_id'] =
          Variable<String>(lastEditedByUserId.value);
    }
    if (categorySyncIdOverride.present) {
      map['category_sync_id_override'] =
          Variable<String>(categorySyncIdOverride.value);
    }
    if (accountSyncIdOverride.present) {
      map['account_sync_id_override'] =
          Variable<String>(accountSyncIdOverride.value);
    }
    if (toAccountSyncIdOverride.present) {
      map['to_account_sync_id_override'] =
          Variable<String>(toAccountSyncIdOverride.value);
    }
    if (tagSyncIdsOverride.present) {
      map['tag_sync_ids_override'] = Variable<String>(tagSyncIdsOverride.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('note: $note, ')
          ..write('recurringId: $recurringId, ')
          ..write('syncId: $syncId, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('lastEditedByUserId: $lastEditedByUserId, ')
          ..write('categorySyncIdOverride: $categorySyncIdOverride, ')
          ..write('accountSyncIdOverride: $accountSyncIdOverride, ')
          ..write('toAccountSyncIdOverride: $toAccountSyncIdOverride, ')
          ..write('tagSyncIdsOverride: $tagSyncIdsOverride')
          ..write(')'))
        .toString();
  }
}

class $RecurringTransactionsTable extends RecurringTransactions
    with TableInfo<$RecurringTransactionsTable, RecurringTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _toAccountIdMeta =
      const VerificationMeta('toAccountId');
  @override
  late final GeneratedColumn<int> toAccountId = GeneratedColumn<int>(
      'to_account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _frequencyMeta =
      const VerificationMeta('frequency');
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
      'frequency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _intervalMeta =
      const VerificationMeta('interval');
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
      'interval', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _dayOfMonthMeta =
      const VerificationMeta('dayOfMonth');
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
      'day_of_month', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _dayOfWeekMeta =
      const VerificationMeta('dayOfWeek');
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
      'day_of_week', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _monthOfYearMeta =
      const VerificationMeta('monthOfYear');
  @override
  late final GeneratedColumn<int> monthOfYear = GeneratedColumn<int>(
      'month_of_year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastGeneratedDateMeta =
      const VerificationMeta('lastGeneratedDate');
  @override
  late final GeneratedColumn<DateTime> lastGeneratedDate =
      GeneratedColumn<DateTime>('last_generated_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ledgerId,
        type,
        amount,
        categoryId,
        accountId,
        toAccountId,
        note,
        frequency,
        interval,
        dayOfMonth,
        dayOfWeek,
        monthOfYear,
        startDate,
        endDate,
        lastGeneratedDate,
        enabled,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_transactions';
  @override
  VerificationContext validateIntegrity(
      Insertable<RecurringTransaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
          _toAccountIdMeta,
          toAccountId.isAcceptableOrUnknown(
              data['to_account_id']!, _toAccountIdMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('frequency')) {
      context.handle(_frequencyMeta,
          frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta));
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(_intervalMeta,
          interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta));
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
          _dayOfMonthMeta,
          dayOfMonth.isAcceptableOrUnknown(
              data['day_of_month']!, _dayOfMonthMeta));
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
          _dayOfWeekMeta,
          dayOfWeek.isAcceptableOrUnknown(
              data['day_of_week']!, _dayOfWeekMeta));
    }
    if (data.containsKey('month_of_year')) {
      context.handle(
          _monthOfYearMeta,
          monthOfYear.isAcceptableOrUnknown(
              data['month_of_year']!, _monthOfYearMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('last_generated_date')) {
      context.handle(
          _lastGeneratedDateMeta,
          lastGeneratedDate.isAcceptableOrUnknown(
              data['last_generated_date']!, _lastGeneratedDateMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringTransaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id']),
      toAccountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}to_account_id']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      frequency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}frequency'])!,
      interval: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}interval'])!,
      dayOfMonth: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_of_month']),
      dayOfWeek: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_of_week']),
      monthOfYear: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}month_of_year']),
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date'])!,
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date']),
      lastGeneratedDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_generated_date']),
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RecurringTransactionsTable createAlias(String alias) {
    return $RecurringTransactionsTable(attachedDatabase, alias);
  }
}

class RecurringTransaction extends DataClass
    implements Insertable<RecurringTransaction> {
  final int id;
  final int ledgerId;
  final String type;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final String? note;
  final String frequency;
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastGeneratedDate;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecurringTransaction(
      {required this.id,
      required this.ledgerId,
      required this.type,
      required this.amount,
      this.categoryId,
      this.accountId,
      this.toAccountId,
      this.note,
      required this.frequency,
      required this.interval,
      this.dayOfMonth,
      this.dayOfWeek,
      this.monthOfYear,
      required this.startDate,
      this.endDate,
      this.lastGeneratedDate,
      required this.enabled,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<int>(toAccountId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['frequency'] = Variable<String>(frequency);
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    if (!nullToAbsent || dayOfWeek != null) {
      map['day_of_week'] = Variable<int>(dayOfWeek);
    }
    if (!nullToAbsent || monthOfYear != null) {
      map['month_of_year'] = Variable<int>(monthOfYear);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || lastGeneratedDate != null) {
      map['last_generated_date'] = Variable<DateTime>(lastGeneratedDate);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecurringTransactionsCompanion toCompanion(bool nullToAbsent) {
    return RecurringTransactionsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      type: Value(type),
      amount: Value(amount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      frequency: Value(frequency),
      interval: Value(interval),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      dayOfWeek: dayOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfWeek),
      monthOfYear: monthOfYear == null && nullToAbsent
          ? const Value.absent()
          : Value(monthOfYear),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      lastGeneratedDate: lastGeneratedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastGeneratedDate),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecurringTransaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringTransaction(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      toAccountId: serializer.fromJson<int?>(json['toAccountId']),
      note: serializer.fromJson<String?>(json['note']),
      frequency: serializer.fromJson<String>(json['frequency']),
      interval: serializer.fromJson<int>(json['interval']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      dayOfWeek: serializer.fromJson<int?>(json['dayOfWeek']),
      monthOfYear: serializer.fromJson<int?>(json['monthOfYear']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      lastGeneratedDate:
          serializer.fromJson<DateTime?>(json['lastGeneratedDate']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'categoryId': serializer.toJson<int?>(categoryId),
      'accountId': serializer.toJson<int?>(accountId),
      'toAccountId': serializer.toJson<int?>(toAccountId),
      'note': serializer.toJson<String?>(note),
      'frequency': serializer.toJson<String>(frequency),
      'interval': serializer.toJson<int>(interval),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'dayOfWeek': serializer.toJson<int?>(dayOfWeek),
      'monthOfYear': serializer.toJson<int?>(monthOfYear),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'lastGeneratedDate': serializer.toJson<DateTime?>(lastGeneratedDate),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecurringTransaction copyWith(
          {int? id,
          int? ledgerId,
          String? type,
          double? amount,
          Value<int?> categoryId = const Value.absent(),
          Value<int?> accountId = const Value.absent(),
          Value<int?> toAccountId = const Value.absent(),
          Value<String?> note = const Value.absent(),
          String? frequency,
          int? interval,
          Value<int?> dayOfMonth = const Value.absent(),
          Value<int?> dayOfWeek = const Value.absent(),
          Value<int?> monthOfYear = const Value.absent(),
          DateTime? startDate,
          Value<DateTime?> endDate = const Value.absent(),
          Value<DateTime?> lastGeneratedDate = const Value.absent(),
          bool? enabled,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      RecurringTransaction(
        id: id ?? this.id,
        ledgerId: ledgerId ?? this.ledgerId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        accountId: accountId.present ? accountId.value : this.accountId,
        toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
        note: note.present ? note.value : this.note,
        frequency: frequency ?? this.frequency,
        interval: interval ?? this.interval,
        dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
        dayOfWeek: dayOfWeek.present ? dayOfWeek.value : this.dayOfWeek,
        monthOfYear: monthOfYear.present ? monthOfYear.value : this.monthOfYear,
        startDate: startDate ?? this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        lastGeneratedDate: lastGeneratedDate.present
            ? lastGeneratedDate.value
            : this.lastGeneratedDate,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RecurringTransaction copyWithCompanion(RecurringTransactionsCompanion data) {
    return RecurringTransaction(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId:
          data.toAccountId.present ? data.toAccountId.value : this.toAccountId,
      note: data.note.present ? data.note.value : this.note,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      interval: data.interval.present ? data.interval.value : this.interval,
      dayOfMonth:
          data.dayOfMonth.present ? data.dayOfMonth.value : this.dayOfMonth,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      monthOfYear:
          data.monthOfYear.present ? data.monthOfYear.value : this.monthOfYear,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      lastGeneratedDate: data.lastGeneratedDate.present
          ? data.lastGeneratedDate.value
          : this.lastGeneratedDate,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransaction(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('note: $note, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('lastGeneratedDate: $lastGeneratedDate, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ledgerId,
      type,
      amount,
      categoryId,
      accountId,
      toAccountId,
      note,
      frequency,
      interval,
      dayOfMonth,
      dayOfWeek,
      monthOfYear,
      startDate,
      endDate,
      lastGeneratedDate,
      enabled,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringTransaction &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.note == this.note &&
          other.frequency == this.frequency &&
          other.interval == this.interval &&
          other.dayOfMonth == this.dayOfMonth &&
          other.dayOfWeek == this.dayOfWeek &&
          other.monthOfYear == this.monthOfYear &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.lastGeneratedDate == this.lastGeneratedDate &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecurringTransactionsCompanion
    extends UpdateCompanion<RecurringTransaction> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<double> amount;
  final Value<int?> categoryId;
  final Value<int?> accountId;
  final Value<int?> toAccountId;
  final Value<String?> note;
  final Value<String> frequency;
  final Value<int> interval;
  final Value<int?> dayOfMonth;
  final Value<int?> dayOfWeek;
  final Value<int?> monthOfYear;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<DateTime?> lastGeneratedDate;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RecurringTransactionsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.note = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.lastGeneratedDate = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RecurringTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String type,
    required double amount,
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.note = const Value.absent(),
    required String frequency,
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.lastGeneratedDate = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        type = Value(type),
        amount = Value(amount),
        frequency = Value(frequency),
        startDate = Value(startDate);
  static Insertable<RecurringTransaction> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<int>? categoryId,
    Expression<int>? accountId,
    Expression<int>? toAccountId,
    Expression<String>? note,
    Expression<String>? frequency,
    Expression<int>? interval,
    Expression<int>? dayOfMonth,
    Expression<int>? dayOfWeek,
    Expression<int>? monthOfYear,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? lastGeneratedDate,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (note != null) 'note': note,
      if (frequency != null) 'frequency': frequency,
      if (interval != null) 'interval': interval,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (monthOfYear != null) 'month_of_year': monthOfYear,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (lastGeneratedDate != null) 'last_generated_date': lastGeneratedDate,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RecurringTransactionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ledgerId,
      Value<String>? type,
      Value<double>? amount,
      Value<int?>? categoryId,
      Value<int?>? accountId,
      Value<int?>? toAccountId,
      Value<String?>? note,
      Value<String>? frequency,
      Value<int>? interval,
      Value<int?>? dayOfMonth,
      Value<int?>? dayOfWeek,
      Value<int?>? monthOfYear,
      Value<DateTime>? startDate,
      Value<DateTime?>? endDate,
      Value<DateTime?>? lastGeneratedDate,
      Value<bool>? enabled,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return RecurringTransactionsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<int>(toAccountId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (monthOfYear.present) {
      map['month_of_year'] = Variable<int>(monthOfYear.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (lastGeneratedDate.present) {
      map['last_generated_date'] = Variable<DateTime>(lastGeneratedDate.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('note: $note, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('lastGeneratedDate: $lastGeneratedDate, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('AI对话'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, ledgerId, title, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<Conversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final int id;
  final int? ledgerId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Conversation(
      {required this.id,
      this.ledgerId,
      required this.title,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || ledgerId != null) {
      map['ledger_id'] = Variable<int>(ledgerId);
    }
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      ledgerId: ledgerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ledgerId),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int?>(json['ledgerId']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int?>(ledgerId),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Conversation copyWith(
          {int? id,
          Value<int?> ledgerId = const Value.absent(),
          String? title,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Conversation(
        id: id ?? this.id,
        ledgerId: ledgerId.present ? ledgerId.value : this.ledgerId,
        title: title ?? this.title,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ledgerId, title, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<int> id;
  final Value<int?> ledgerId;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<Conversation> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ConversationsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? ledgerId,
      Value<String>? title,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return ConversationsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageTypeMeta =
      const VerificationMeta('messageType');
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
      'message_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        role,
        content,
        messageType,
        metadata,
        transactionId,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
          _messageTypeMeta,
          messageType.isAcceptableOrUnknown(
              data['message_type']!, _messageTypeMeta));
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conversation_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final int conversationId;
  final String role;
  final String content;
  final String messageType;
  final String? metadata;
  final int? transactionId;
  final DateTime createdAt;
  const Message(
      {required this.id,
      required this.conversationId,
      required this.role,
      required this.content,
      required this.messageType,
      this.metadata,
      this.transactionId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['message_type'] = Variable<String>(messageType);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      messageType: Value(messageType),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      createdAt: Value(createdAt),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      messageType: serializer.fromJson<String>(json['messageType']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'messageType': serializer.toJson<String>(messageType),
      'metadata': serializer.toJson<String?>(metadata),
      'transactionId': serializer.toJson<int?>(transactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Message copyWith(
          {int? id,
          int? conversationId,
          String? role,
          String? content,
          String? messageType,
          Value<String?> metadata = const Value.absent(),
          Value<int?> transactionId = const Value.absent(),
          DateTime? createdAt}) =>
      Message(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        role: role ?? this.role,
        content: content ?? this.content,
        messageType: messageType ?? this.messageType,
        metadata: metadata.present ? metadata.value : this.metadata,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
        createdAt: createdAt ?? this.createdAt,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('metadata: $metadata, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, role, content,
      messageType, metadata, transactionId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.messageType == this.messageType &&
          other.metadata == this.metadata &&
          other.transactionId == this.transactionId &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<int> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> messageType;
  final Value<String?> metadata;
  final Value<int?> transactionId;
  final Value<DateTime> createdAt;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.messageType = const Value.absent(),
    this.metadata = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required String role,
    required String content,
    required String messageType,
    this.metadata = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : conversationId = Value(conversationId),
        role = Value(role),
        content = Value(content),
        messageType = Value(messageType);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? messageType,
    Expression<String>? metadata,
    Expression<int>? transactionId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (messageType != null) 'message_type': messageType,
      if (metadata != null) 'metadata': metadata,
      if (transactionId != null) 'transaction_id': transactionId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MessagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? conversationId,
      Value<String>? role,
      Value<String>? content,
      Value<String>? messageType,
      Value<String?>? metadata,
      Value<int?>? transactionId,
      Value<DateTime>? createdAt}) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('metadata: $metadata, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, color, sortOrder, createdAt, syncId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final String? color;
  final int sortOrder;
  final DateTime createdAt;
  final String? syncId;
  const Tag(
      {required this.id,
      required this.name,
      this.color,
      required this.sortOrder,
      required this.createdAt,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Tag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Tag copyWith(
          {int? id,
          String? name,
          Value<String?> color = const Value.absent(),
          int? sortOrder,
          DateTime? createdAt,
          Value<String?> syncId = const Value.absent()}) =>
      Tag(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color.present ? color.value : this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, sortOrder, createdAt, syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.syncId == this.syncId);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> color;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<String?> syncId;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  TagsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? color,
      Value<int>? sortOrder,
      Value<DateTime>? createdAt,
      Value<String?>? syncId}) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      syncId: syncId ?? this.syncId,
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
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $TransactionTagsTable extends TransactionTags
    with TableInfo<$TransactionTagsTable, TransactionTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, transactionId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_tags';
  @override
  VerificationContext validateIntegrity(Insertable<TransactionTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionTag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $TransactionTagsTable createAlias(String alias) {
    return $TransactionTagsTable(attachedDatabase, alias);
  }
}

class TransactionTag extends DataClass implements Insertable<TransactionTag> {
  final int id;
  final int transactionId;
  final int tagId;
  const TransactionTag(
      {required this.id, required this.transactionId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<int>(transactionId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  TransactionTagsCompanion toCompanion(bool nullToAbsent) {
    return TransactionTagsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      tagId: Value(tagId),
    );
  }

  factory TransactionTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionTag(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int>(transactionId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  TransactionTag copyWith({int? id, int? transactionId, int? tagId}) =>
      TransactionTag(
        id: id ?? this.id,
        transactionId: transactionId ?? this.transactionId,
        tagId: tagId ?? this.tagId,
      );
  TransactionTag copyWithCompanion(TransactionTagsCompanion data) {
    return TransactionTag(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTag(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, transactionId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionTag &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.tagId == this.tagId);
}

class TransactionTagsCompanion extends UpdateCompanion<TransactionTag> {
  final Value<int> id;
  final Value<int> transactionId;
  final Value<int> tagId;
  const TransactionTagsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.tagId = const Value.absent(),
  });
  TransactionTagsCompanion.insert({
    this.id = const Value.absent(),
    required int transactionId,
    required int tagId,
  })  : transactionId = Value(transactionId),
        tagId = Value(tagId);
  static Insertable<TransactionTag> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<int>? tagId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (tagId != null) 'tag_id': tagId,
    });
  }

  TransactionTagsCompanion copyWith(
      {Value<int>? id, Value<int>? transactionId, Value<int>? tagId}) {
    return TransactionTagsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      tagId: tagId ?? this.tagId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTagsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('total'));
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
      'period', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('monthly'));
  static const VerificationMeta _startDayMeta =
      const VerificationMeta('startDay');
  @override
  late final GeneratedColumn<int> startDay = GeneratedColumn<int>(
      'start_day', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        syncId,
        ledgerId,
        type,
        categoryId,
        amount,
        period,
        startDay,
        enabled,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(Insertable<Budget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('period')) {
      context.handle(_periodMeta,
          period.isAcceptableOrUnknown(data['period']!, _periodMeta));
    }
    if (data.containsKey('start_day')) {
      context.handle(_startDayMeta,
          startDay.isAcceptableOrUnknown(data['start_day']!, _startDayMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      period: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}period'])!,
      startDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_day'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final int id;

  /// 跨设备同步 syncId(UUID)。v22 新增,migration 给老行补 UUID;之后每次 create
  /// 都必须填。server 端按此做 entity_sync_id,跨设备 LWW 合并。
  final String? syncId;

  /// 关联账本ID
  final int ledgerId;

  /// 预算类型：total-总预算, category-分类预算
  final String type;

  /// 关联分类ID（仅分类预算有值）
  final int? categoryId;

  /// 预算金额
  final double amount;

  /// 预算周期：monthly-月度, weekly-周度, yearly-年度
  final String period;

  /// 周期起始日（1-31，月度预算；1-7，周度预算）
  final int startDay;

  /// 是否启用
  final bool enabled;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;
  const Budget(
      {required this.id,
      this.syncId,
      required this.ledgerId,
      required this.type,
      this.categoryId,
      required this.amount,
      required this.period,
      required this.startDay,
      required this.enabled,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['amount'] = Variable<double>(amount);
    map['period'] = Variable<String>(period);
    map['start_day'] = Variable<int>(startDay);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
      ledgerId: Value(ledgerId),
      type: Value(type),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: Value(amount),
      period: Value(period),
      startDay: Value(startDay),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Budget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<int>(json['id']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      period: serializer.fromJson<String>(json['period']),
      startDay: serializer.fromJson<int>(json['startDay']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'syncId': serializer.toJson<String?>(syncId),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'categoryId': serializer.toJson<int?>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'period': serializer.toJson<String>(period),
      'startDay': serializer.toJson<int>(startDay),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Budget copyWith(
          {int? id,
          Value<String?> syncId = const Value.absent(),
          int? ledgerId,
          String? type,
          Value<int?> categoryId = const Value.absent(),
          double? amount,
          String? period,
          int? startDay,
          bool? enabled,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Budget(
        id: id ?? this.id,
        syncId: syncId.present ? syncId.value : this.syncId,
        ledgerId: ledgerId ?? this.ledgerId,
        type: type ?? this.type,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        amount: amount ?? this.amount,
        period: period ?? this.period,
        startDay: startDay ?? this.startDay,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      period: data.period.present ? data.period.value : this.period,
      startDay: data.startDay.present ? data.startDay.value : this.startDay,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('startDay: $startDay, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, syncId, ledgerId, type, categoryId,
      amount, period, startDay, enabled, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.syncId == this.syncId &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.period == this.period &&
          other.startDay == this.startDay &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<int> id;
  final Value<String?> syncId;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<int?> categoryId;
  final Value<double> amount;
  final Value<String> period;
  final Value<int> startDay;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.period = const Value.absent(),
    this.startDay = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BudgetsCompanion.insert({
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    required int ledgerId,
    this.type = const Value.absent(),
    this.categoryId = const Value.absent(),
    required double amount,
    this.period = const Value.absent(),
    this.startDay = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        amount = Value(amount);
  static Insertable<Budget> custom({
    Expression<int>? id,
    Expression<String>? syncId,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<int>? categoryId,
    Expression<double>? amount,
    Expression<String>? period,
    Expression<int>? startDay,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (syncId != null) 'sync_id': syncId,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (period != null) 'period': period,
      if (startDay != null) 'start_day': startDay,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BudgetsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? syncId,
      Value<int>? ledgerId,
      Value<String>? type,
      Value<int?>? categoryId,
      Value<double>? amount,
      Value<String>? period,
      Value<int>? startDay,
      Value<bool>? enabled,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return BudgetsCompanion(
      id: id ?? this.id,
      syncId: syncId ?? this.syncId,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDay: startDay ?? this.startDay,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (startDay.present) {
      map['start_day'] = Variable<int>(startDay.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('startDay: $startDay, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionAttachmentsTable extends TransactionAttachments
    with TableInfo<$TransactionAttachmentsTable, TransactionAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalNameMeta =
      const VerificationMeta('originalName');
  @override
  late final GeneratedColumn<String> originalName = GeneratedColumn<String>(
      'original_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
      'width', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
      'height', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _cloudFileIdMeta =
      const VerificationMeta('cloudFileId');
  @override
  late final GeneratedColumn<String> cloudFileId = GeneratedColumn<String>(
      'cloud_file_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cloudSha256Meta =
      const VerificationMeta('cloudSha256');
  @override
  late final GeneratedColumn<String> cloudSha256 = GeneratedColumn<String>(
      'cloud_sha256', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        transactionId,
        fileName,
        originalName,
        fileSize,
        width,
        height,
        sortOrder,
        cloudFileId,
        cloudSha256,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_attachments';
  @override
  VerificationContext validateIntegrity(
      Insertable<TransactionAttachment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('original_name')) {
      context.handle(
          _originalNameMeta,
          originalName.isAcceptableOrUnknown(
              data['original_name']!, _originalNameMeta));
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
          _widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('cloud_file_id')) {
      context.handle(
          _cloudFileIdMeta,
          cloudFileId.isAcceptableOrUnknown(
              data['cloud_file_id']!, _cloudFileIdMeta));
    }
    if (data.containsKey('cloud_sha256')) {
      context.handle(
          _cloudSha256Meta,
          cloudSha256.isAcceptableOrUnknown(
              data['cloud_sha256']!, _cloudSha256Meta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionAttachment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name'])!,
      originalName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}original_name']),
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size']),
      width: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}width']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      cloudFileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cloud_file_id']),
      cloudSha256: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cloud_sha256']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TransactionAttachmentsTable createAlias(String alias) {
    return $TransactionAttachmentsTable(attachedDatabase, alias);
  }
}

class TransactionAttachment extends DataClass
    implements Insertable<TransactionAttachment> {
  final int id;
  final int transactionId;
  final String fileName;
  final String? originalName;
  final int? fileSize;
  final int? width;
  final int? height;
  final int sortOrder;
  final String? cloudFileId;
  final String? cloudSha256;
  final DateTime createdAt;
  const TransactionAttachment(
      {required this.id,
      required this.transactionId,
      required this.fileName,
      this.originalName,
      this.fileSize,
      this.width,
      this.height,
      required this.sortOrder,
      this.cloudFileId,
      this.cloudSha256,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<int>(transactionId);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || originalName != null) {
      map['original_name'] = Variable<String>(originalName);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || cloudFileId != null) {
      map['cloud_file_id'] = Variable<String>(cloudFileId);
    }
    if (!nullToAbsent || cloudSha256 != null) {
      map['cloud_sha256'] = Variable<String>(cloudSha256);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransactionAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return TransactionAttachmentsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      fileName: Value(fileName),
      originalName: originalName == null && nullToAbsent
          ? const Value.absent()
          : Value(originalName),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      width:
          width == null && nullToAbsent ? const Value.absent() : Value(width),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      sortOrder: Value(sortOrder),
      cloudFileId: cloudFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudFileId),
      cloudSha256: cloudSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudSha256),
      createdAt: Value(createdAt),
    );
  }

  factory TransactionAttachment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionAttachment(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      originalName: serializer.fromJson<String?>(json['originalName']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      cloudFileId: serializer.fromJson<String?>(json['cloudFileId']),
      cloudSha256: serializer.fromJson<String?>(json['cloudSha256']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int>(transactionId),
      'fileName': serializer.toJson<String>(fileName),
      'originalName': serializer.toJson<String?>(originalName),
      'fileSize': serializer.toJson<int?>(fileSize),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'cloudFileId': serializer.toJson<String?>(cloudFileId),
      'cloudSha256': serializer.toJson<String?>(cloudSha256),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TransactionAttachment copyWith(
          {int? id,
          int? transactionId,
          String? fileName,
          Value<String?> originalName = const Value.absent(),
          Value<int?> fileSize = const Value.absent(),
          Value<int?> width = const Value.absent(),
          Value<int?> height = const Value.absent(),
          int? sortOrder,
          Value<String?> cloudFileId = const Value.absent(),
          Value<String?> cloudSha256 = const Value.absent(),
          DateTime? createdAt}) =>
      TransactionAttachment(
        id: id ?? this.id,
        transactionId: transactionId ?? this.transactionId,
        fileName: fileName ?? this.fileName,
        originalName:
            originalName.present ? originalName.value : this.originalName,
        fileSize: fileSize.present ? fileSize.value : this.fileSize,
        width: width.present ? width.value : this.width,
        height: height.present ? height.value : this.height,
        sortOrder: sortOrder ?? this.sortOrder,
        cloudFileId: cloudFileId.present ? cloudFileId.value : this.cloudFileId,
        cloudSha256: cloudSha256.present ? cloudSha256.value : this.cloudSha256,
        createdAt: createdAt ?? this.createdAt,
      );
  TransactionAttachment copyWithCompanion(
      TransactionAttachmentsCompanion data) {
    return TransactionAttachment(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      originalName: data.originalName.present
          ? data.originalName.value
          : this.originalName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      cloudFileId:
          data.cloudFileId.present ? data.cloudFileId.value : this.cloudFileId,
      cloudSha256:
          data.cloudSha256.present ? data.cloudSha256.value : this.cloudSha256,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAttachment(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('fileName: $fileName, ')
          ..write('originalName: $originalName, ')
          ..write('fileSize: $fileSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cloudFileId: $cloudFileId, ')
          ..write('cloudSha256: $cloudSha256, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, transactionId, fileName, originalName,
      fileSize, width, height, sortOrder, cloudFileId, cloudSha256, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionAttachment &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.fileName == this.fileName &&
          other.originalName == this.originalName &&
          other.fileSize == this.fileSize &&
          other.width == this.width &&
          other.height == this.height &&
          other.sortOrder == this.sortOrder &&
          other.cloudFileId == this.cloudFileId &&
          other.cloudSha256 == this.cloudSha256 &&
          other.createdAt == this.createdAt);
}

class TransactionAttachmentsCompanion
    extends UpdateCompanion<TransactionAttachment> {
  final Value<int> id;
  final Value<int> transactionId;
  final Value<String> fileName;
  final Value<String?> originalName;
  final Value<int?> fileSize;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int> sortOrder;
  final Value<String?> cloudFileId;
  final Value<String?> cloudSha256;
  final Value<DateTime> createdAt;
  const TransactionAttachmentsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.originalName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.cloudFileId = const Value.absent(),
    this.cloudSha256 = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TransactionAttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required int transactionId,
    required String fileName,
    this.originalName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.cloudFileId = const Value.absent(),
    this.cloudSha256 = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : transactionId = Value(transactionId),
        fileName = Value(fileName);
  static Insertable<TransactionAttachment> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<String>? fileName,
    Expression<String>? originalName,
    Expression<int>? fileSize,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? sortOrder,
    Expression<String>? cloudFileId,
    Expression<String>? cloudSha256,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (fileName != null) 'file_name': fileName,
      if (originalName != null) 'original_name': originalName,
      if (fileSize != null) 'file_size': fileSize,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (cloudFileId != null) 'cloud_file_id': cloudFileId,
      if (cloudSha256 != null) 'cloud_sha256': cloudSha256,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransactionAttachmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? transactionId,
      Value<String>? fileName,
      Value<String?>? originalName,
      Value<int?>? fileSize,
      Value<int?>? width,
      Value<int?>? height,
      Value<int>? sortOrder,
      Value<String?>? cloudFileId,
      Value<String?>? cloudSha256,
      Value<DateTime>? createdAt}) {
    return TransactionAttachmentsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      fileName: fileName ?? this.fileName,
      originalName: originalName ?? this.originalName,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      sortOrder: sortOrder ?? this.sortOrder,
      cloudFileId: cloudFileId ?? this.cloudFileId,
      cloudSha256: cloudSha256 ?? this.cloudSha256,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (originalName.present) {
      map['original_name'] = Variable<String>(originalName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (cloudFileId.present) {
      map['cloud_file_id'] = Variable<String>(cloudFileId.value);
    }
    if (cloudSha256.present) {
      map['cloud_sha256'] = Variable<String>(cloudSha256.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('fileName: $fileName, ')
          ..write('originalName: $originalName, ')
          ..write('fileSize: $fileSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cloudFileId: $cloudFileId, ')
          ..write('cloudSha256: $cloudSha256, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalChangesTable extends LocalChanges
    with TableInfo<$LocalChangesTable, LocalChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _entitySyncIdMeta =
      const VerificationMeta('entitySyncId');
  @override
  late final GeneratedColumn<String> entitySyncId = GeneratedColumn<String>(
      'entity_sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _pushedAtMeta =
      const VerificationMeta('pushedAt');
  @override
  late final GeneratedColumn<DateTime> pushedAt = GeneratedColumn<DateTime>(
      'pushed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityType,
        entityId,
        entitySyncId,
        ledgerId,
        action,
        payloadJson,
        createdAt,
        pushedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_changes';
  @override
  VerificationContext validateIntegrity(Insertable<LocalChange> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_sync_id')) {
      context.handle(
          _entitySyncIdMeta,
          entitySyncId.isAcceptableOrUnknown(
              data['entity_sync_id']!, _entitySyncIdMeta));
    } else if (isInserting) {
      context.missing(_entitySyncIdMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('pushed_at')) {
      context.handle(_pushedAtMeta,
          pushedAt.isAcceptableOrUnknown(data['pushed_at']!, _pushedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChange(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}entity_id'])!,
      entitySyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_sync_id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      pushedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}pushed_at']),
    );
  }

  @override
  $LocalChangesTable createAlias(String alias) {
    return $LocalChangesTable(attachedDatabase, alias);
  }
}

class LocalChange extends DataClass implements Insertable<LocalChange> {
  final int id;
  final String entityType;
  final int entityId;
  final String entitySyncId;
  final int ledgerId;
  final String action;
  final String? payloadJson;
  final DateTime createdAt;
  final DateTime? pushedAt;
  const LocalChange(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.entitySyncId,
      required this.ledgerId,
      required this.action,
      this.payloadJson,
      required this.createdAt,
      this.pushedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<int>(entityId);
    map['entity_sync_id'] = Variable<String>(entitySyncId);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || pushedAt != null) {
      map['pushed_at'] = Variable<DateTime>(pushedAt);
    }
    return map;
  }

  LocalChangesCompanion toCompanion(bool nullToAbsent) {
    return LocalChangesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      entitySyncId: Value(entitySyncId),
      ledgerId: Value(ledgerId),
      action: Value(action),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      createdAt: Value(createdAt),
      pushedAt: pushedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pushedAt),
    );
  }

  factory LocalChange.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChange(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<int>(json['entityId']),
      entitySyncId: serializer.fromJson<String>(json['entitySyncId']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      action: serializer.fromJson<String>(json['action']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pushedAt: serializer.fromJson<DateTime?>(json['pushedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<int>(entityId),
      'entitySyncId': serializer.toJson<String>(entitySyncId),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'action': serializer.toJson<String>(action),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pushedAt': serializer.toJson<DateTime?>(pushedAt),
    };
  }

  LocalChange copyWith(
          {int? id,
          String? entityType,
          int? entityId,
          String? entitySyncId,
          int? ledgerId,
          String? action,
          Value<String?> payloadJson = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> pushedAt = const Value.absent()}) =>
      LocalChange(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        entitySyncId: entitySyncId ?? this.entitySyncId,
        ledgerId: ledgerId ?? this.ledgerId,
        action: action ?? this.action,
        payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
        createdAt: createdAt ?? this.createdAt,
        pushedAt: pushedAt.present ? pushedAt.value : this.pushedAt,
      );
  LocalChange copyWithCompanion(LocalChangesCompanion data) {
    return LocalChange(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entitySyncId: data.entitySyncId.present
          ? data.entitySyncId.value
          : this.entitySyncId,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      action: data.action.present ? data.action.value : this.action,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pushedAt: data.pushedAt.present ? data.pushedAt.value : this.pushedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChange(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, entityId, entitySyncId,
      ledgerId, action, payloadJson, createdAt, pushedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChange &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.entitySyncId == this.entitySyncId &&
          other.ledgerId == this.ledgerId &&
          other.action == this.action &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.pushedAt == this.pushedAt);
}

class LocalChangesCompanion extends UpdateCompanion<LocalChange> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<int> entityId;
  final Value<String> entitySyncId;
  final Value<int> ledgerId;
  final Value<String> action;
  final Value<String?> payloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> pushedAt;
  const LocalChangesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entitySyncId = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.action = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  });
  LocalChangesCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  })  : entityType = Value(entityType),
        entityId = Value(entityId),
        entitySyncId = Value(entitySyncId),
        ledgerId = Value(ledgerId),
        action = Value(action);
  static Insertable<LocalChange> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<int>? entityId,
    Expression<String>? entitySyncId,
    Expression<int>? ledgerId,
    Expression<String>? action,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? pushedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (entitySyncId != null) 'entity_sync_id': entitySyncId,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (action != null) 'action': action,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (pushedAt != null) 'pushed_at': pushedAt,
    });
  }

  LocalChangesCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityType,
      Value<int>? entityId,
      Value<String>? entitySyncId,
      Value<int>? ledgerId,
      Value<String>? action,
      Value<String?>? payloadJson,
      Value<DateTime>? createdAt,
      Value<DateTime?>? pushedAt}) {
    return LocalChangesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entitySyncId: entitySyncId ?? this.entitySyncId,
      ledgerId: ledgerId ?? this.ledgerId,
      action: action ?? this.action,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      pushedAt: pushedAt ?? this.pushedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (entitySyncId.present) {
      map['entity_sync_id'] = Variable<String>(entitySyncId.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pushedAt.present) {
      map['pushed_at'] = Variable<DateTime>(pushedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalChangesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerTypeMeta =
      const VerificationMeta('providerType');
  @override
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
      'provider_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('beecount_cloud'));
  static const VerificationMeta _serverCursorMeta =
      const VerificationMeta('serverCursor');
  @override
  late final GeneratedColumn<int> serverCursor = GeneratedColumn<int>(
      'server_cursor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastPushAtMeta =
      const VerificationMeta('lastPushAt');
  @override
  late final GeneratedColumn<DateTime> lastPushAt = GeneratedColumn<DateTime>(
      'last_push_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastPullAtMeta =
      const VerificationMeta('lastPullAt');
  @override
  late final GeneratedColumn<DateTime> lastPullAt = GeneratedColumn<DateTime>(
      'last_pull_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, deviceId, providerType, serverCursor, lastPushAt, lastPullAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(Insertable<SyncStateData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('provider_type')) {
      context.handle(
          _providerTypeMeta,
          providerType.isAcceptableOrUnknown(
              data['provider_type']!, _providerTypeMeta));
    }
    if (data.containsKey('server_cursor')) {
      context.handle(
          _serverCursorMeta,
          serverCursor.isAcceptableOrUnknown(
              data['server_cursor']!, _serverCursorMeta));
    }
    if (data.containsKey('last_push_at')) {
      context.handle(
          _lastPushAtMeta,
          lastPushAt.isAcceptableOrUnknown(
              data['last_push_at']!, _lastPushAtMeta));
    }
    if (data.containsKey('last_pull_at')) {
      context.handle(
          _lastPullAtMeta,
          lastPullAt.isAcceptableOrUnknown(
              data['last_pull_at']!, _lastPullAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      providerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_type'])!,
      serverCursor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_cursor'])!,
      lastPushAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_push_at']),
      lastPullAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_pull_at']),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final int id;
  final String deviceId;
  final String providerType;
  final int serverCursor;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;
  const SyncStateData(
      {required this.id,
      required this.deviceId,
      required this.providerType,
      required this.serverCursor,
      this.lastPushAt,
      this.lastPullAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['provider_type'] = Variable<String>(providerType);
    map['server_cursor'] = Variable<int>(serverCursor);
    if (!nullToAbsent || lastPushAt != null) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt);
    }
    if (!nullToAbsent || lastPullAt != null) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      providerType: Value(providerType),
      serverCursor: Value(serverCursor),
      lastPushAt: lastPushAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushAt),
      lastPullAt: lastPullAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPullAt),
    );
  }

  factory SyncStateData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      providerType: serializer.fromJson<String>(json['providerType']),
      serverCursor: serializer.fromJson<int>(json['serverCursor']),
      lastPushAt: serializer.fromJson<DateTime?>(json['lastPushAt']),
      lastPullAt: serializer.fromJson<DateTime?>(json['lastPullAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'providerType': serializer.toJson<String>(providerType),
      'serverCursor': serializer.toJson<int>(serverCursor),
      'lastPushAt': serializer.toJson<DateTime?>(lastPushAt),
      'lastPullAt': serializer.toJson<DateTime?>(lastPullAt),
    };
  }

  SyncStateData copyWith(
          {int? id,
          String? deviceId,
          String? providerType,
          int? serverCursor,
          Value<DateTime?> lastPushAt = const Value.absent(),
          Value<DateTime?> lastPullAt = const Value.absent()}) =>
      SyncStateData(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        providerType: providerType ?? this.providerType,
        serverCursor: serverCursor ?? this.serverCursor,
        lastPushAt: lastPushAt.present ? lastPushAt.value : this.lastPushAt,
        lastPullAt: lastPullAt.present ? lastPullAt.value : this.lastPullAt,
      );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      serverCursor: data.serverCursor.present
          ? data.serverCursor.value
          : this.serverCursor,
      lastPushAt:
          data.lastPushAt.present ? data.lastPushAt.value : this.lastPushAt,
      lastPullAt:
          data.lastPullAt.present ? data.lastPullAt.value : this.lastPullAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('providerType: $providerType, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('lastPullAt: $lastPullAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, deviceId, providerType, serverCursor, lastPushAt, lastPullAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.providerType == this.providerType &&
          other.serverCursor == this.serverCursor &&
          other.lastPushAt == this.lastPushAt &&
          other.lastPullAt == this.lastPullAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String> providerType;
  final Value<int> serverCursor;
  final Value<DateTime?> lastPushAt;
  final Value<DateTime?> lastPullAt;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.providerType = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.lastPullAt = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    this.providerType = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.lastPullAt = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<SyncStateData> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? providerType,
    Expression<int>? serverCursor,
    Expression<DateTime>? lastPushAt,
    Expression<DateTime>? lastPullAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (providerType != null) 'provider_type': providerType,
      if (serverCursor != null) 'server_cursor': serverCursor,
      if (lastPushAt != null) 'last_push_at': lastPushAt,
      if (lastPullAt != null) 'last_pull_at': lastPullAt,
    });
  }

  SyncStateCompanion copyWith(
      {Value<int>? id,
      Value<String>? deviceId,
      Value<String>? providerType,
      Value<int>? serverCursor,
      Value<DateTime?>? lastPushAt,
      Value<DateTime?>? lastPullAt}) {
    return SyncStateCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      providerType: providerType ?? this.providerType,
      serverCursor: serverCursor ?? this.serverCursor,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      lastPullAt: lastPullAt ?? this.lastPullAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (serverCursor.present) {
      map['server_cursor'] = Variable<int>(serverCursor.value);
    }
    if (lastPushAt.present) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt.value);
    }
    if (lastPullAt.present) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('providerType: $providerType, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('lastPullAt: $lastPullAt')
          ..write(')'))
        .toString();
  }
}

class $LedgerMembersTable extends LedgerMembers
    with TableInfo<$LedgerMembersTable, LedgerMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerSyncIdMeta =
      const VerificationMeta('ledgerSyncId');
  @override
  late final GeneratedColumn<String> ledgerSyncId = GeneratedColumn<String>(
      'ledger_sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _joinedAtMeta =
      const VerificationMeta('joinedAt');
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
      'joined_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        ledgerSyncId,
        userId,
        email,
        displayName,
        avatarUrl,
        role,
        joinedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_members';
  @override
  VerificationContext validateIntegrity(Insertable<LedgerMember> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_sync_id')) {
      context.handle(
          _ledgerSyncIdMeta,
          ledgerSyncId.isAcceptableOrUnknown(
              data['ledger_sync_id']!, _ledgerSyncIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerSyncIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(_joinedAtMeta,
          joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta));
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerSyncId, userId};
  @override
  LedgerMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerMember(
      ledgerSyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ledger_sync_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      joinedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}joined_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LedgerMembersTable createAlias(String alias) {
    return $LedgerMembersTable(attachedDatabase, alias);
  }
}

class LedgerMember extends DataClass implements Insertable<LedgerMember> {
  final String ledgerSyncId;
  final String userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;
  final DateTime updatedAt;
  const LedgerMember(
      {required this.ledgerSyncId,
      required this.userId,
      this.email,
      this.displayName,
      this.avatarUrl,
      required this.role,
      required this.joinedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_sync_id'] = Variable<String>(ledgerSyncId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LedgerMembersCompanion toCompanion(bool nullToAbsent) {
    return LedgerMembersCompanion(
      ledgerSyncId: Value(ledgerSyncId),
      userId: Value(userId),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      role: Value(role),
      joinedAt: Value(joinedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LedgerMember.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerMember(
      ledgerSyncId: serializer.fromJson<String>(json['ledgerSyncId']),
      userId: serializer.fromJson<String>(json['userId']),
      email: serializer.fromJson<String?>(json['email']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerSyncId': serializer.toJson<String>(ledgerSyncId),
      'userId': serializer.toJson<String>(userId),
      'email': serializer.toJson<String?>(email),
      'displayName': serializer.toJson<String?>(displayName),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LedgerMember copyWith(
          {String? ledgerSyncId,
          String? userId,
          Value<String?> email = const Value.absent(),
          Value<String?> displayName = const Value.absent(),
          Value<String?> avatarUrl = const Value.absent(),
          String? role,
          DateTime? joinedAt,
          DateTime? updatedAt}) =>
      LedgerMember(
        ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
        userId: userId ?? this.userId,
        email: email.present ? email.value : this.email,
        displayName: displayName.present ? displayName.value : this.displayName,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
        role: role ?? this.role,
        joinedAt: joinedAt ?? this.joinedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LedgerMember copyWithCompanion(LedgerMembersCompanion data) {
    return LedgerMember(
      ledgerSyncId: data.ledgerSyncId.present
          ? data.ledgerSyncId.value
          : this.ledgerSyncId,
      userId: data.userId.present ? data.userId.value : this.userId,
      email: data.email.present ? data.email.value : this.email,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerMember(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ledgerSyncId, userId, email, displayName,
      avatarUrl, role, joinedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerMember &&
          other.ledgerSyncId == this.ledgerSyncId &&
          other.userId == this.userId &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.avatarUrl == this.avatarUrl &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt &&
          other.updatedAt == this.updatedAt);
}

class LedgerMembersCompanion extends UpdateCompanion<LedgerMember> {
  final Value<String> ledgerSyncId;
  final Value<String> userId;
  final Value<String?> email;
  final Value<String?> displayName;
  final Value<String?> avatarUrl;
  final Value<String> role;
  final Value<DateTime> joinedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LedgerMembersCompanion({
    this.ledgerSyncId = const Value.absent(),
    this.userId = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerMembersCompanion.insert({
    required String ledgerSyncId,
    required String userId,
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    required String role,
    required DateTime joinedAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : ledgerSyncId = Value(ledgerSyncId),
        userId = Value(userId),
        role = Value(role),
        joinedAt = Value(joinedAt),
        updatedAt = Value(updatedAt);
  static Insertable<LedgerMember> custom({
    Expression<String>? ledgerSyncId,
    Expression<String>? userId,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? avatarUrl,
    Expression<String>? role,
    Expression<DateTime>? joinedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ledgerSyncId != null) 'ledger_sync_id': ledgerSyncId,
      if (userId != null) 'user_id': userId,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerMembersCompanion copyWith(
      {Value<String>? ledgerSyncId,
      Value<String>? userId,
      Value<String?>? email,
      Value<String?>? displayName,
      Value<String?>? avatarUrl,
      Value<String>? role,
      Value<DateTime>? joinedAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LedgerMembersCompanion(
      ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerSyncId.present) {
      map['ledger_sync_id'] = Variable<String>(ledgerSyncId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerMembersCompanion(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedLedgerCategoriesTable extends SharedLedgerCategories
    with TableInfo<$SharedLedgerCategoriesTable, SharedLedgerCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedLedgerCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerSyncIdMeta =
      const VerificationMeta('ledgerSyncId');
  @override
  late final GeneratedColumn<String> ledgerSyncId = GeneratedColumn<String>(
      'ledger_sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconTypeMeta =
      const VerificationMeta('iconType');
  @override
  late final GeneratedColumn<String> iconType = GeneratedColumn<String>(
      'icon_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('material'));
  static const VerificationMeta _iconCloudFileIdMeta =
      const VerificationMeta('iconCloudFileId');
  @override
  late final GeneratedColumn<String> iconCloudFileId = GeneratedColumn<String>(
      'icon_cloud_file_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconCloudSha256Meta =
      const VerificationMeta('iconCloudSha256');
  @override
  late final GeneratedColumn<String> iconCloudSha256 = GeneratedColumn<String>(
      'icon_cloud_sha256', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
      'level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _parentNameMeta =
      const VerificationMeta('parentName');
  @override
  late final GeneratedColumn<String> parentName = GeneratedColumn<String>(
      'parent_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentSyncIdMeta =
      const VerificationMeta('parentSyncId');
  @override
  late final GeneratedColumn<String> parentSyncId = GeneratedColumn<String>(
      'parent_sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        ledgerSyncId,
        syncId,
        name,
        kind,
        icon,
        iconType,
        iconCloudFileId,
        iconCloudSha256,
        color,
        sortOrder,
        level,
        parentName,
        parentSyncId,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_ledger_categories';
  @override
  VerificationContext validateIntegrity(
      Insertable<SharedLedgerCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_sync_id')) {
      context.handle(
          _ledgerSyncIdMeta,
          ledgerSyncId.isAcceptableOrUnknown(
              data['ledger_sync_id']!, _ledgerSyncIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerSyncIdMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('icon_type')) {
      context.handle(_iconTypeMeta,
          iconType.isAcceptableOrUnknown(data['icon_type']!, _iconTypeMeta));
    }
    if (data.containsKey('icon_cloud_file_id')) {
      context.handle(
          _iconCloudFileIdMeta,
          iconCloudFileId.isAcceptableOrUnknown(
              data['icon_cloud_file_id']!, _iconCloudFileIdMeta));
    }
    if (data.containsKey('icon_cloud_sha256')) {
      context.handle(
          _iconCloudSha256Meta,
          iconCloudSha256.isAcceptableOrUnknown(
              data['icon_cloud_sha256']!, _iconCloudSha256Meta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('parent_name')) {
      context.handle(
          _parentNameMeta,
          parentName.isAcceptableOrUnknown(
              data['parent_name']!, _parentNameMeta));
    }
    if (data.containsKey('parent_sync_id')) {
      context.handle(
          _parentSyncIdMeta,
          parentSyncId.isAcceptableOrUnknown(
              data['parent_sync_id']!, _parentSyncIdMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerSyncId, syncId};
  @override
  SharedLedgerCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedLedgerCategory(
      ledgerSyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ledger_sync_id'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon']),
      iconType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_type'])!,
      iconCloudFileId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}icon_cloud_file_id']),
      iconCloudSha256: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}icon_cloud_sha256']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level'])!,
      parentName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_name']),
      parentSyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_sync_id']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SharedLedgerCategoriesTable createAlias(String alias) {
    return $SharedLedgerCategoriesTable(attachedDatabase, alias);
  }
}

class SharedLedgerCategory extends DataClass
    implements Insertable<SharedLedgerCategory> {
  final String ledgerSyncId;
  final String syncId;
  final String name;
  final String kind;
  final String? icon;
  final String iconType;
  final String? iconCloudFileId;
  final String? iconCloudSha256;
  final String? color;
  final int sortOrder;
  final int level;
  final String? parentName;
  final String? parentSyncId;
  final DateTime updatedAt;
  const SharedLedgerCategory(
      {required this.ledgerSyncId,
      required this.syncId,
      required this.name,
      required this.kind,
      this.icon,
      required this.iconType,
      this.iconCloudFileId,
      this.iconCloudSha256,
      this.color,
      required this.sortOrder,
      required this.level,
      this.parentName,
      this.parentSyncId,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_sync_id'] = Variable<String>(ledgerSyncId);
    map['sync_id'] = Variable<String>(syncId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['icon_type'] = Variable<String>(iconType);
    if (!nullToAbsent || iconCloudFileId != null) {
      map['icon_cloud_file_id'] = Variable<String>(iconCloudFileId);
    }
    if (!nullToAbsent || iconCloudSha256 != null) {
      map['icon_cloud_sha256'] = Variable<String>(iconCloudSha256);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['level'] = Variable<int>(level);
    if (!nullToAbsent || parentName != null) {
      map['parent_name'] = Variable<String>(parentName);
    }
    if (!nullToAbsent || parentSyncId != null) {
      map['parent_sync_id'] = Variable<String>(parentSyncId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SharedLedgerCategoriesCompanion toCompanion(bool nullToAbsent) {
    return SharedLedgerCategoriesCompanion(
      ledgerSyncId: Value(ledgerSyncId),
      syncId: Value(syncId),
      name: Value(name),
      kind: Value(kind),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      iconType: Value(iconType),
      iconCloudFileId: iconCloudFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(iconCloudFileId),
      iconCloudSha256: iconCloudSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(iconCloudSha256),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      sortOrder: Value(sortOrder),
      level: Value(level),
      parentName: parentName == null && nullToAbsent
          ? const Value.absent()
          : Value(parentName),
      parentSyncId: parentSyncId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSyncId),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedLedgerCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedLedgerCategory(
      ledgerSyncId: serializer.fromJson<String>(json['ledgerSyncId']),
      syncId: serializer.fromJson<String>(json['syncId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      icon: serializer.fromJson<String?>(json['icon']),
      iconType: serializer.fromJson<String>(json['iconType']),
      iconCloudFileId: serializer.fromJson<String?>(json['iconCloudFileId']),
      iconCloudSha256: serializer.fromJson<String?>(json['iconCloudSha256']),
      color: serializer.fromJson<String?>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      level: serializer.fromJson<int>(json['level']),
      parentName: serializer.fromJson<String?>(json['parentName']),
      parentSyncId: serializer.fromJson<String?>(json['parentSyncId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerSyncId': serializer.toJson<String>(ledgerSyncId),
      'syncId': serializer.toJson<String>(syncId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'icon': serializer.toJson<String?>(icon),
      'iconType': serializer.toJson<String>(iconType),
      'iconCloudFileId': serializer.toJson<String?>(iconCloudFileId),
      'iconCloudSha256': serializer.toJson<String?>(iconCloudSha256),
      'color': serializer.toJson<String?>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'level': serializer.toJson<int>(level),
      'parentName': serializer.toJson<String?>(parentName),
      'parentSyncId': serializer.toJson<String?>(parentSyncId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SharedLedgerCategory copyWith(
          {String? ledgerSyncId,
          String? syncId,
          String? name,
          String? kind,
          Value<String?> icon = const Value.absent(),
          String? iconType,
          Value<String?> iconCloudFileId = const Value.absent(),
          Value<String?> iconCloudSha256 = const Value.absent(),
          Value<String?> color = const Value.absent(),
          int? sortOrder,
          int? level,
          Value<String?> parentName = const Value.absent(),
          Value<String?> parentSyncId = const Value.absent(),
          DateTime? updatedAt}) =>
      SharedLedgerCategory(
        ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
        syncId: syncId ?? this.syncId,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        icon: icon.present ? icon.value : this.icon,
        iconType: iconType ?? this.iconType,
        iconCloudFileId: iconCloudFileId.present
            ? iconCloudFileId.value
            : this.iconCloudFileId,
        iconCloudSha256: iconCloudSha256.present
            ? iconCloudSha256.value
            : this.iconCloudSha256,
        color: color.present ? color.value : this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        level: level ?? this.level,
        parentName: parentName.present ? parentName.value : this.parentName,
        parentSyncId:
            parentSyncId.present ? parentSyncId.value : this.parentSyncId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SharedLedgerCategory copyWithCompanion(SharedLedgerCategoriesCompanion data) {
    return SharedLedgerCategory(
      ledgerSyncId: data.ledgerSyncId.present
          ? data.ledgerSyncId.value
          : this.ledgerSyncId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      icon: data.icon.present ? data.icon.value : this.icon,
      iconType: data.iconType.present ? data.iconType.value : this.iconType,
      iconCloudFileId: data.iconCloudFileId.present
          ? data.iconCloudFileId.value
          : this.iconCloudFileId,
      iconCloudSha256: data.iconCloudSha256.present
          ? data.iconCloudSha256.value
          : this.iconCloudSha256,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      level: data.level.present ? data.level.value : this.level,
      parentName:
          data.parentName.present ? data.parentName.value : this.parentName,
      parentSyncId: data.parentSyncId.present
          ? data.parentSyncId.value
          : this.parentSyncId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerCategory(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('iconType: $iconType, ')
          ..write('iconCloudFileId: $iconCloudFileId, ')
          ..write('iconCloudSha256: $iconCloudSha256, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('level: $level, ')
          ..write('parentName: $parentName, ')
          ..write('parentSyncId: $parentSyncId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      ledgerSyncId,
      syncId,
      name,
      kind,
      icon,
      iconType,
      iconCloudFileId,
      iconCloudSha256,
      color,
      sortOrder,
      level,
      parentName,
      parentSyncId,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedLedgerCategory &&
          other.ledgerSyncId == this.ledgerSyncId &&
          other.syncId == this.syncId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.icon == this.icon &&
          other.iconType == this.iconType &&
          other.iconCloudFileId == this.iconCloudFileId &&
          other.iconCloudSha256 == this.iconCloudSha256 &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.level == this.level &&
          other.parentName == this.parentName &&
          other.parentSyncId == this.parentSyncId &&
          other.updatedAt == this.updatedAt);
}

class SharedLedgerCategoriesCompanion
    extends UpdateCompanion<SharedLedgerCategory> {
  final Value<String> ledgerSyncId;
  final Value<String> syncId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> icon;
  final Value<String> iconType;
  final Value<String?> iconCloudFileId;
  final Value<String?> iconCloudSha256;
  final Value<String?> color;
  final Value<int> sortOrder;
  final Value<int> level;
  final Value<String?> parentName;
  final Value<String?> parentSyncId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SharedLedgerCategoriesCompanion({
    this.ledgerSyncId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.icon = const Value.absent(),
    this.iconType = const Value.absent(),
    this.iconCloudFileId = const Value.absent(),
    this.iconCloudSha256 = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.level = const Value.absent(),
    this.parentName = const Value.absent(),
    this.parentSyncId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedLedgerCategoriesCompanion.insert({
    required String ledgerSyncId,
    required String syncId,
    required String name,
    required String kind,
    this.icon = const Value.absent(),
    this.iconType = const Value.absent(),
    this.iconCloudFileId = const Value.absent(),
    this.iconCloudSha256 = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.level = const Value.absent(),
    this.parentName = const Value.absent(),
    this.parentSyncId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : ledgerSyncId = Value(ledgerSyncId),
        syncId = Value(syncId),
        name = Value(name),
        kind = Value(kind),
        updatedAt = Value(updatedAt);
  static Insertable<SharedLedgerCategory> custom({
    Expression<String>? ledgerSyncId,
    Expression<String>? syncId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? icon,
    Expression<String>? iconType,
    Expression<String>? iconCloudFileId,
    Expression<String>? iconCloudSha256,
    Expression<String>? color,
    Expression<int>? sortOrder,
    Expression<int>? level,
    Expression<String>? parentName,
    Expression<String>? parentSyncId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ledgerSyncId != null) 'ledger_sync_id': ledgerSyncId,
      if (syncId != null) 'sync_id': syncId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (icon != null) 'icon': icon,
      if (iconType != null) 'icon_type': iconType,
      if (iconCloudFileId != null) 'icon_cloud_file_id': iconCloudFileId,
      if (iconCloudSha256 != null) 'icon_cloud_sha256': iconCloudSha256,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (level != null) 'level': level,
      if (parentName != null) 'parent_name': parentName,
      if (parentSyncId != null) 'parent_sync_id': parentSyncId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedLedgerCategoriesCompanion copyWith(
      {Value<String>? ledgerSyncId,
      Value<String>? syncId,
      Value<String>? name,
      Value<String>? kind,
      Value<String?>? icon,
      Value<String>? iconType,
      Value<String?>? iconCloudFileId,
      Value<String?>? iconCloudSha256,
      Value<String?>? color,
      Value<int>? sortOrder,
      Value<int>? level,
      Value<String?>? parentName,
      Value<String?>? parentSyncId,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SharedLedgerCategoriesCompanion(
      ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      icon: icon ?? this.icon,
      iconType: iconType ?? this.iconType,
      iconCloudFileId: iconCloudFileId ?? this.iconCloudFileId,
      iconCloudSha256: iconCloudSha256 ?? this.iconCloudSha256,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      level: level ?? this.level,
      parentName: parentName ?? this.parentName,
      parentSyncId: parentSyncId ?? this.parentSyncId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerSyncId.present) {
      map['ledger_sync_id'] = Variable<String>(ledgerSyncId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (iconType.present) {
      map['icon_type'] = Variable<String>(iconType.value);
    }
    if (iconCloudFileId.present) {
      map['icon_cloud_file_id'] = Variable<String>(iconCloudFileId.value);
    }
    if (iconCloudSha256.present) {
      map['icon_cloud_sha256'] = Variable<String>(iconCloudSha256.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (parentName.present) {
      map['parent_name'] = Variable<String>(parentName.value);
    }
    if (parentSyncId.present) {
      map['parent_sync_id'] = Variable<String>(parentSyncId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerCategoriesCompanion(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('iconType: $iconType, ')
          ..write('iconCloudFileId: $iconCloudFileId, ')
          ..write('iconCloudSha256: $iconCloudSha256, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('level: $level, ')
          ..write('parentName: $parentName, ')
          ..write('parentSyncId: $parentSyncId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedLedgerAccountsTable extends SharedLedgerAccounts
    with TableInfo<$SharedLedgerAccountsTable, SharedLedgerAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedLedgerAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerSyncIdMeta =
      const VerificationMeta('ledgerSyncId');
  @override
  late final GeneratedColumn<String> ledgerSyncId = GeneratedColumn<String>(
      'ledger_sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountTypeMeta =
      const VerificationMeta('accountType');
  @override
  late final GeneratedColumn<String> accountType = GeneratedColumn<String>(
      'account_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('cash'));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _initialBalanceMeta =
      const VerificationMeta('initialBalance');
  @override
  late final GeneratedColumn<double> initialBalance = GeneratedColumn<double>(
      'initial_balance', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _creditLimitMeta =
      const VerificationMeta('creditLimit');
  @override
  late final GeneratedColumn<double> creditLimit = GeneratedColumn<double>(
      'credit_limit', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _billingDayMeta =
      const VerificationMeta('billingDay');
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
      'billing_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _paymentDueDayMeta =
      const VerificationMeta('paymentDueDay');
  @override
  late final GeneratedColumn<int> paymentDueDay = GeneratedColumn<int>(
      'payment_due_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bankNameMeta =
      const VerificationMeta('bankName');
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
      'bank_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cardLastFourMeta =
      const VerificationMeta('cardLastFour');
  @override
  late final GeneratedColumn<String> cardLastFour = GeneratedColumn<String>(
      'card_last_four', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        ledgerSyncId,
        syncId,
        name,
        accountType,
        currency,
        note,
        initialBalance,
        creditLimit,
        billingDay,
        paymentDueDay,
        bankName,
        cardLastFour,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_ledger_accounts';
  @override
  VerificationContext validateIntegrity(
      Insertable<SharedLedgerAccount> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_sync_id')) {
      context.handle(
          _ledgerSyncIdMeta,
          ledgerSyncId.isAcceptableOrUnknown(
              data['ledger_sync_id']!, _ledgerSyncIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerSyncIdMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('account_type')) {
      context.handle(
          _accountTypeMeta,
          accountType.isAcceptableOrUnknown(
              data['account_type']!, _accountTypeMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
          _initialBalanceMeta,
          initialBalance.isAcceptableOrUnknown(
              data['initial_balance']!, _initialBalanceMeta));
    }
    if (data.containsKey('credit_limit')) {
      context.handle(
          _creditLimitMeta,
          creditLimit.isAcceptableOrUnknown(
              data['credit_limit']!, _creditLimitMeta));
    }
    if (data.containsKey('billing_day')) {
      context.handle(
          _billingDayMeta,
          billingDay.isAcceptableOrUnknown(
              data['billing_day']!, _billingDayMeta));
    }
    if (data.containsKey('payment_due_day')) {
      context.handle(
          _paymentDueDayMeta,
          paymentDueDay.isAcceptableOrUnknown(
              data['payment_due_day']!, _paymentDueDayMeta));
    }
    if (data.containsKey('bank_name')) {
      context.handle(_bankNameMeta,
          bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta));
    }
    if (data.containsKey('card_last_four')) {
      context.handle(
          _cardLastFourMeta,
          cardLastFour.isAcceptableOrUnknown(
              data['card_last_four']!, _cardLastFourMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerSyncId, syncId};
  @override
  SharedLedgerAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedLedgerAccount(
      ledgerSyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ledger_sync_id'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      accountType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_type'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      initialBalance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}initial_balance']),
      creditLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}credit_limit']),
      billingDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}billing_day']),
      paymentDueDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment_due_day']),
      bankName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bank_name']),
      cardLastFour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_last_four']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SharedLedgerAccountsTable createAlias(String alias) {
    return $SharedLedgerAccountsTable(attachedDatabase, alias);
  }
}

class SharedLedgerAccount extends DataClass
    implements Insertable<SharedLedgerAccount> {
  final String ledgerSyncId;
  final String syncId;
  final String name;
  final String accountType;
  final String currency;
  final String? note;
  final double? initialBalance;
  final double? creditLimit;
  final int? billingDay;
  final int? paymentDueDay;
  final String? bankName;
  final String? cardLastFour;
  final DateTime updatedAt;
  const SharedLedgerAccount(
      {required this.ledgerSyncId,
      required this.syncId,
      required this.name,
      required this.accountType,
      required this.currency,
      this.note,
      this.initialBalance,
      this.creditLimit,
      this.billingDay,
      this.paymentDueDay,
      this.bankName,
      this.cardLastFour,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_sync_id'] = Variable<String>(ledgerSyncId);
    map['sync_id'] = Variable<String>(syncId);
    map['name'] = Variable<String>(name);
    map['account_type'] = Variable<String>(accountType);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || initialBalance != null) {
      map['initial_balance'] = Variable<double>(initialBalance);
    }
    if (!nullToAbsent || creditLimit != null) {
      map['credit_limit'] = Variable<double>(creditLimit);
    }
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || paymentDueDay != null) {
      map['payment_due_day'] = Variable<int>(paymentDueDay);
    }
    if (!nullToAbsent || bankName != null) {
      map['bank_name'] = Variable<String>(bankName);
    }
    if (!nullToAbsent || cardLastFour != null) {
      map['card_last_four'] = Variable<String>(cardLastFour);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SharedLedgerAccountsCompanion toCompanion(bool nullToAbsent) {
    return SharedLedgerAccountsCompanion(
      ledgerSyncId: Value(ledgerSyncId),
      syncId: Value(syncId),
      name: Value(name),
      accountType: Value(accountType),
      currency: Value(currency),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      initialBalance: initialBalance == null && nullToAbsent
          ? const Value.absent()
          : Value(initialBalance),
      creditLimit: creditLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimit),
      billingDay: billingDay == null && nullToAbsent
          ? const Value.absent()
          : Value(billingDay),
      paymentDueDay: paymentDueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentDueDay),
      bankName: bankName == null && nullToAbsent
          ? const Value.absent()
          : Value(bankName),
      cardLastFour: cardLastFour == null && nullToAbsent
          ? const Value.absent()
          : Value(cardLastFour),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedLedgerAccount.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedLedgerAccount(
      ledgerSyncId: serializer.fromJson<String>(json['ledgerSyncId']),
      syncId: serializer.fromJson<String>(json['syncId']),
      name: serializer.fromJson<String>(json['name']),
      accountType: serializer.fromJson<String>(json['accountType']),
      currency: serializer.fromJson<String>(json['currency']),
      note: serializer.fromJson<String?>(json['note']),
      initialBalance: serializer.fromJson<double?>(json['initialBalance']),
      creditLimit: serializer.fromJson<double?>(json['creditLimit']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      paymentDueDay: serializer.fromJson<int?>(json['paymentDueDay']),
      bankName: serializer.fromJson<String?>(json['bankName']),
      cardLastFour: serializer.fromJson<String?>(json['cardLastFour']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerSyncId': serializer.toJson<String>(ledgerSyncId),
      'syncId': serializer.toJson<String>(syncId),
      'name': serializer.toJson<String>(name),
      'accountType': serializer.toJson<String>(accountType),
      'currency': serializer.toJson<String>(currency),
      'note': serializer.toJson<String?>(note),
      'initialBalance': serializer.toJson<double?>(initialBalance),
      'creditLimit': serializer.toJson<double?>(creditLimit),
      'billingDay': serializer.toJson<int?>(billingDay),
      'paymentDueDay': serializer.toJson<int?>(paymentDueDay),
      'bankName': serializer.toJson<String?>(bankName),
      'cardLastFour': serializer.toJson<String?>(cardLastFour),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SharedLedgerAccount copyWith(
          {String? ledgerSyncId,
          String? syncId,
          String? name,
          String? accountType,
          String? currency,
          Value<String?> note = const Value.absent(),
          Value<double?> initialBalance = const Value.absent(),
          Value<double?> creditLimit = const Value.absent(),
          Value<int?> billingDay = const Value.absent(),
          Value<int?> paymentDueDay = const Value.absent(),
          Value<String?> bankName = const Value.absent(),
          Value<String?> cardLastFour = const Value.absent(),
          DateTime? updatedAt}) =>
      SharedLedgerAccount(
        ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
        syncId: syncId ?? this.syncId,
        name: name ?? this.name,
        accountType: accountType ?? this.accountType,
        currency: currency ?? this.currency,
        note: note.present ? note.value : this.note,
        initialBalance:
            initialBalance.present ? initialBalance.value : this.initialBalance,
        creditLimit: creditLimit.present ? creditLimit.value : this.creditLimit,
        billingDay: billingDay.present ? billingDay.value : this.billingDay,
        paymentDueDay:
            paymentDueDay.present ? paymentDueDay.value : this.paymentDueDay,
        bankName: bankName.present ? bankName.value : this.bankName,
        cardLastFour:
            cardLastFour.present ? cardLastFour.value : this.cardLastFour,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SharedLedgerAccount copyWithCompanion(SharedLedgerAccountsCompanion data) {
    return SharedLedgerAccount(
      ledgerSyncId: data.ledgerSyncId.present
          ? data.ledgerSyncId.value
          : this.ledgerSyncId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      name: data.name.present ? data.name.value : this.name,
      accountType:
          data.accountType.present ? data.accountType.value : this.accountType,
      currency: data.currency.present ? data.currency.value : this.currency,
      note: data.note.present ? data.note.value : this.note,
      initialBalance: data.initialBalance.present
          ? data.initialBalance.value
          : this.initialBalance,
      creditLimit:
          data.creditLimit.present ? data.creditLimit.value : this.creditLimit,
      billingDay:
          data.billingDay.present ? data.billingDay.value : this.billingDay,
      paymentDueDay: data.paymentDueDay.present
          ? data.paymentDueDay.value
          : this.paymentDueDay,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      cardLastFour: data.cardLastFour.present
          ? data.cardLastFour.value
          : this.cardLastFour,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerAccount(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('accountType: $accountType, ')
          ..write('currency: $currency, ')
          ..write('note: $note, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('bankName: $bankName, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      ledgerSyncId,
      syncId,
      name,
      accountType,
      currency,
      note,
      initialBalance,
      creditLimit,
      billingDay,
      paymentDueDay,
      bankName,
      cardLastFour,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedLedgerAccount &&
          other.ledgerSyncId == this.ledgerSyncId &&
          other.syncId == this.syncId &&
          other.name == this.name &&
          other.accountType == this.accountType &&
          other.currency == this.currency &&
          other.note == this.note &&
          other.initialBalance == this.initialBalance &&
          other.creditLimit == this.creditLimit &&
          other.billingDay == this.billingDay &&
          other.paymentDueDay == this.paymentDueDay &&
          other.bankName == this.bankName &&
          other.cardLastFour == this.cardLastFour &&
          other.updatedAt == this.updatedAt);
}

class SharedLedgerAccountsCompanion
    extends UpdateCompanion<SharedLedgerAccount> {
  final Value<String> ledgerSyncId;
  final Value<String> syncId;
  final Value<String> name;
  final Value<String> accountType;
  final Value<String> currency;
  final Value<String?> note;
  final Value<double?> initialBalance;
  final Value<double?> creditLimit;
  final Value<int?> billingDay;
  final Value<int?> paymentDueDay;
  final Value<String?> bankName;
  final Value<String?> cardLastFour;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SharedLedgerAccountsCompanion({
    this.ledgerSyncId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.name = const Value.absent(),
    this.accountType = const Value.absent(),
    this.currency = const Value.absent(),
    this.note = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.bankName = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedLedgerAccountsCompanion.insert({
    required String ledgerSyncId,
    required String syncId,
    required String name,
    this.accountType = const Value.absent(),
    this.currency = const Value.absent(),
    this.note = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.bankName = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : ledgerSyncId = Value(ledgerSyncId),
        syncId = Value(syncId),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<SharedLedgerAccount> custom({
    Expression<String>? ledgerSyncId,
    Expression<String>? syncId,
    Expression<String>? name,
    Expression<String>? accountType,
    Expression<String>? currency,
    Expression<String>? note,
    Expression<double>? initialBalance,
    Expression<double>? creditLimit,
    Expression<int>? billingDay,
    Expression<int>? paymentDueDay,
    Expression<String>? bankName,
    Expression<String>? cardLastFour,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ledgerSyncId != null) 'ledger_sync_id': ledgerSyncId,
      if (syncId != null) 'sync_id': syncId,
      if (name != null) 'name': name,
      if (accountType != null) 'account_type': accountType,
      if (currency != null) 'currency': currency,
      if (note != null) 'note': note,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (billingDay != null) 'billing_day': billingDay,
      if (paymentDueDay != null) 'payment_due_day': paymentDueDay,
      if (bankName != null) 'bank_name': bankName,
      if (cardLastFour != null) 'card_last_four': cardLastFour,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedLedgerAccountsCompanion copyWith(
      {Value<String>? ledgerSyncId,
      Value<String>? syncId,
      Value<String>? name,
      Value<String>? accountType,
      Value<String>? currency,
      Value<String?>? note,
      Value<double?>? initialBalance,
      Value<double?>? creditLimit,
      Value<int?>? billingDay,
      Value<int?>? paymentDueDay,
      Value<String?>? bankName,
      Value<String?>? cardLastFour,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SharedLedgerAccountsCompanion(
      ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      currency: currency ?? this.currency,
      note: note ?? this.note,
      initialBalance: initialBalance ?? this.initialBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      billingDay: billingDay ?? this.billingDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      bankName: bankName ?? this.bankName,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerSyncId.present) {
      map['ledger_sync_id'] = Variable<String>(ledgerSyncId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (accountType.present) {
      map['account_type'] = Variable<String>(accountType.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<double>(initialBalance.value);
    }
    if (creditLimit.present) {
      map['credit_limit'] = Variable<double>(creditLimit.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (paymentDueDay.present) {
      map['payment_due_day'] = Variable<int>(paymentDueDay.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (cardLastFour.present) {
      map['card_last_four'] = Variable<String>(cardLastFour.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerAccountsCompanion(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('accountType: $accountType, ')
          ..write('currency: $currency, ')
          ..write('note: $note, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('bankName: $bankName, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedLedgerTagsTable extends SharedLedgerTags
    with TableInfo<$SharedLedgerTagsTable, SharedLedgerTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedLedgerTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerSyncIdMeta =
      const VerificationMeta('ledgerSyncId');
  @override
  late final GeneratedColumn<String> ledgerSyncId = GeneratedColumn<String>(
      'ledger_sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [ledgerSyncId, syncId, name, color, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_ledger_tags';
  @override
  VerificationContext validateIntegrity(Insertable<SharedLedgerTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_sync_id')) {
      context.handle(
          _ledgerSyncIdMeta,
          ledgerSyncId.isAcceptableOrUnknown(
              data['ledger_sync_id']!, _ledgerSyncIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerSyncIdMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerSyncId, syncId};
  @override
  SharedLedgerTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedLedgerTag(
      ledgerSyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ledger_sync_id'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SharedLedgerTagsTable createAlias(String alias) {
    return $SharedLedgerTagsTable(attachedDatabase, alias);
  }
}

class SharedLedgerTag extends DataClass implements Insertable<SharedLedgerTag> {
  final String ledgerSyncId;
  final String syncId;
  final String name;
  final String? color;
  final DateTime updatedAt;
  const SharedLedgerTag(
      {required this.ledgerSyncId,
      required this.syncId,
      required this.name,
      this.color,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_sync_id'] = Variable<String>(ledgerSyncId);
    map['sync_id'] = Variable<String>(syncId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SharedLedgerTagsCompanion toCompanion(bool nullToAbsent) {
    return SharedLedgerTagsCompanion(
      ledgerSyncId: Value(ledgerSyncId),
      syncId: Value(syncId),
      name: Value(name),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedLedgerTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedLedgerTag(
      ledgerSyncId: serializer.fromJson<String>(json['ledgerSyncId']),
      syncId: serializer.fromJson<String>(json['syncId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerSyncId': serializer.toJson<String>(ledgerSyncId),
      'syncId': serializer.toJson<String>(syncId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SharedLedgerTag copyWith(
          {String? ledgerSyncId,
          String? syncId,
          String? name,
          Value<String?> color = const Value.absent(),
          DateTime? updatedAt}) =>
      SharedLedgerTag(
        ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
        syncId: syncId ?? this.syncId,
        name: name ?? this.name,
        color: color.present ? color.value : this.color,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SharedLedgerTag copyWithCompanion(SharedLedgerTagsCompanion data) {
    return SharedLedgerTag(
      ledgerSyncId: data.ledgerSyncId.present
          ? data.ledgerSyncId.value
          : this.ledgerSyncId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerTag(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ledgerSyncId, syncId, name, color, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedLedgerTag &&
          other.ledgerSyncId == this.ledgerSyncId &&
          other.syncId == this.syncId &&
          other.name == this.name &&
          other.color == this.color &&
          other.updatedAt == this.updatedAt);
}

class SharedLedgerTagsCompanion extends UpdateCompanion<SharedLedgerTag> {
  final Value<String> ledgerSyncId;
  final Value<String> syncId;
  final Value<String> name;
  final Value<String?> color;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SharedLedgerTagsCompanion({
    this.ledgerSyncId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedLedgerTagsCompanion.insert({
    required String ledgerSyncId,
    required String syncId,
    required String name,
    this.color = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : ledgerSyncId = Value(ledgerSyncId),
        syncId = Value(syncId),
        name = Value(name),
        updatedAt = Value(updatedAt);
  static Insertable<SharedLedgerTag> custom({
    Expression<String>? ledgerSyncId,
    Expression<String>? syncId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ledgerSyncId != null) 'ledger_sync_id': ledgerSyncId,
      if (syncId != null) 'sync_id': syncId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedLedgerTagsCompanion copyWith(
      {Value<String>? ledgerSyncId,
      Value<String>? syncId,
      Value<String>? name,
      Value<String?>? color,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SharedLedgerTagsCompanion(
      ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerSyncId.present) {
      map['ledger_sync_id'] = Variable<String>(ledgerSyncId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerTagsCompanion(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionTagOverridesTable extends TransactionTagOverrides
    with TableInfo<$TransactionTagOverridesTable, TransactionTagOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionTagOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transactionSyncIdMeta =
      const VerificationMeta('transactionSyncId');
  @override
  late final GeneratedColumn<String> transactionSyncId =
      GeneratedColumn<String>('transaction_sync_id', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagSyncIdMeta =
      const VerificationMeta('tagSyncId');
  @override
  late final GeneratedColumn<String> tagSyncId = GeneratedColumn<String>(
      'tag_sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [transactionSyncId, tagSyncId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_tag_overrides';
  @override
  VerificationContext validateIntegrity(
      Insertable<TransactionTagOverride> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transaction_sync_id')) {
      context.handle(
          _transactionSyncIdMeta,
          transactionSyncId.isAcceptableOrUnknown(
              data['transaction_sync_id']!, _transactionSyncIdMeta));
    } else if (isInserting) {
      context.missing(_transactionSyncIdMeta);
    }
    if (data.containsKey('tag_sync_id')) {
      context.handle(
          _tagSyncIdMeta,
          tagSyncId.isAcceptableOrUnknown(
              data['tag_sync_id']!, _tagSyncIdMeta));
    } else if (isInserting) {
      context.missing(_tagSyncIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transactionSyncId, tagSyncId};
  @override
  TransactionTagOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionTagOverride(
      transactionSyncId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}transaction_sync_id'])!,
      tagSyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_sync_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TransactionTagOverridesTable createAlias(String alias) {
    return $TransactionTagOverridesTable(attachedDatabase, alias);
  }
}

class TransactionTagOverride extends DataClass
    implements Insertable<TransactionTagOverride> {
  final String transactionSyncId;
  final String tagSyncId;
  final DateTime createdAt;
  const TransactionTagOverride(
      {required this.transactionSyncId,
      required this.tagSyncId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transaction_sync_id'] = Variable<String>(transactionSyncId);
    map['tag_sync_id'] = Variable<String>(tagSyncId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransactionTagOverridesCompanion toCompanion(bool nullToAbsent) {
    return TransactionTagOverridesCompanion(
      transactionSyncId: Value(transactionSyncId),
      tagSyncId: Value(tagSyncId),
      createdAt: Value(createdAt),
    );
  }

  factory TransactionTagOverride.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionTagOverride(
      transactionSyncId: serializer.fromJson<String>(json['transactionSyncId']),
      tagSyncId: serializer.fromJson<String>(json['tagSyncId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transactionSyncId': serializer.toJson<String>(transactionSyncId),
      'tagSyncId': serializer.toJson<String>(tagSyncId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TransactionTagOverride copyWith(
          {String? transactionSyncId,
          String? tagSyncId,
          DateTime? createdAt}) =>
      TransactionTagOverride(
        transactionSyncId: transactionSyncId ?? this.transactionSyncId,
        tagSyncId: tagSyncId ?? this.tagSyncId,
        createdAt: createdAt ?? this.createdAt,
      );
  TransactionTagOverride copyWithCompanion(
      TransactionTagOverridesCompanion data) {
    return TransactionTagOverride(
      transactionSyncId: data.transactionSyncId.present
          ? data.transactionSyncId.value
          : this.transactionSyncId,
      tagSyncId: data.tagSyncId.present ? data.tagSyncId.value : this.tagSyncId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTagOverride(')
          ..write('transactionSyncId: $transactionSyncId, ')
          ..write('tagSyncId: $tagSyncId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transactionSyncId, tagSyncId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionTagOverride &&
          other.transactionSyncId == this.transactionSyncId &&
          other.tagSyncId == this.tagSyncId &&
          other.createdAt == this.createdAt);
}

class TransactionTagOverridesCompanion
    extends UpdateCompanion<TransactionTagOverride> {
  final Value<String> transactionSyncId;
  final Value<String> tagSyncId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TransactionTagOverridesCompanion({
    this.transactionSyncId = const Value.absent(),
    this.tagSyncId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionTagOverridesCompanion.insert({
    required String transactionSyncId,
    required String tagSyncId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : transactionSyncId = Value(transactionSyncId),
        tagSyncId = Value(tagSyncId),
        createdAt = Value(createdAt);
  static Insertable<TransactionTagOverride> custom({
    Expression<String>? transactionSyncId,
    Expression<String>? tagSyncId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transactionSyncId != null) 'transaction_sync_id': transactionSyncId,
      if (tagSyncId != null) 'tag_sync_id': tagSyncId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionTagOverridesCompanion copyWith(
      {Value<String>? transactionSyncId,
      Value<String>? tagSyncId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return TransactionTagOverridesCompanion(
      transactionSyncId: transactionSyncId ?? this.transactionSyncId,
      tagSyncId: tagSyncId ?? this.tagSyncId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transactionSyncId.present) {
      map['transaction_sync_id'] = Variable<String>(transactionSyncId.value);
    }
    if (tagSyncId.present) {
      map['tag_sync_id'] = Variable<String>(tagSyncId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTagOverridesCompanion(')
          ..write('transactionSyncId: $transactionSyncId, ')
          ..write('tagSyncId: $tagSyncId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BeeDatabase extends GeneratedDatabase {
  _$BeeDatabase(QueryExecutor e) : super(e);
  $BeeDatabaseManager get managers => $BeeDatabaseManager(this);
  late final $LedgersTable ledgers = $LedgersTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $RecurringTransactionsTable recurringTransactions =
      $RecurringTransactionsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TransactionTagsTable transactionTags =
      $TransactionTagsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $TransactionAttachmentsTable transactionAttachments =
      $TransactionAttachmentsTable(this);
  late final $LocalChangesTable localChanges = $LocalChangesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $LedgerMembersTable ledgerMembers = $LedgerMembersTable(this);
  late final $SharedLedgerCategoriesTable sharedLedgerCategories =
      $SharedLedgerCategoriesTable(this);
  late final $SharedLedgerAccountsTable sharedLedgerAccounts =
      $SharedLedgerAccountsTable(this);
  late final $SharedLedgerTagsTable sharedLedgerTags =
      $SharedLedgerTagsTable(this);
  late final $TransactionTagOverridesTable transactionTagOverrides =
      $TransactionTagOverridesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        ledgers,
        accounts,
        categories,
        transactions,
        recurringTransactions,
        conversations,
        messages,
        tags,
        transactionTags,
        budgets,
        transactionAttachments,
        localChanges,
        syncState,
        ledgerMembers,
        sharedLedgerCategories,
        sharedLedgerAccounts,
        sharedLedgerTags,
        transactionTagOverrides
      ];
}

typedef $$LedgersTableCreateCompanionBuilder = LedgersCompanion Function({
  Value<int> id,
  required String name,
  Value<String> currency,
  Value<String> type,
  Value<DateTime> createdAt,
  Value<String?> syncId,
  Value<String> myRole,
  Value<int> memberCount,
  Value<bool> isShared,
  Value<String?> ownerUserId,
});
typedef $$LedgersTableUpdateCompanionBuilder = LedgersCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> currency,
  Value<String> type,
  Value<DateTime> createdAt,
  Value<String?> syncId,
  Value<String> myRole,
  Value<int> memberCount,
  Value<bool> isShared,
  Value<String?> ownerUserId,
});

class $$LedgersTableFilterComposer
    extends Composer<_$BeeDatabase, $LedgersTable> {
  $$LedgersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get myRole => $composableBuilder(
      column: $table.myRole, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get memberCount => $composableBuilder(
      column: $table.memberCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isShared => $composableBuilder(
      column: $table.isShared, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnFilters(column));
}

class $$LedgersTableOrderingComposer
    extends Composer<_$BeeDatabase, $LedgersTable> {
  $$LedgersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get myRole => $composableBuilder(
      column: $table.myRole, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get memberCount => $composableBuilder(
      column: $table.memberCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isShared => $composableBuilder(
      column: $table.isShared, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnOrderings(column));
}

class $$LedgersTableAnnotationComposer
    extends Composer<_$BeeDatabase, $LedgersTable> {
  $$LedgersTableAnnotationComposer({
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

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get myRole =>
      $composableBuilder(column: $table.myRole, builder: (column) => column);

  GeneratedColumn<int> get memberCount => $composableBuilder(
      column: $table.memberCount, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => column);
}

class $$LedgersTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $LedgersTable,
    Ledger,
    $$LedgersTableFilterComposer,
    $$LedgersTableOrderingComposer,
    $$LedgersTableAnnotationComposer,
    $$LedgersTableCreateCompanionBuilder,
    $$LedgersTableUpdateCompanionBuilder,
    (Ledger, BaseReferences<_$BeeDatabase, $LedgersTable, Ledger>),
    Ledger,
    PrefetchHooks Function()> {
  $$LedgersTableTableManager(_$BeeDatabase db, $LedgersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<String> myRole = const Value.absent(),
            Value<int> memberCount = const Value.absent(),
            Value<bool> isShared = const Value.absent(),
            Value<String?> ownerUserId = const Value.absent(),
          }) =>
              LedgersCompanion(
            id: id,
            name: name,
            currency: currency,
            type: type,
            createdAt: createdAt,
            syncId: syncId,
            myRole: myRole,
            memberCount: memberCount,
            isShared: isShared,
            ownerUserId: ownerUserId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> currency = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<String> myRole = const Value.absent(),
            Value<int> memberCount = const Value.absent(),
            Value<bool> isShared = const Value.absent(),
            Value<String?> ownerUserId = const Value.absent(),
          }) =>
              LedgersCompanion.insert(
            id: id,
            name: name,
            currency: currency,
            type: type,
            createdAt: createdAt,
            syncId: syncId,
            myRole: myRole,
            memberCount: memberCount,
            isShared: isShared,
            ownerUserId: ownerUserId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LedgersTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $LedgersTable,
    Ledger,
    $$LedgersTableFilterComposer,
    $$LedgersTableOrderingComposer,
    $$LedgersTableAnnotationComposer,
    $$LedgersTableCreateCompanionBuilder,
    $$LedgersTableUpdateCompanionBuilder,
    (Ledger, BaseReferences<_$BeeDatabase, $LedgersTable, Ledger>),
    Ledger,
    PrefetchHooks Function()>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  required int ledgerId,
  required String name,
  Value<String> type,
  Value<String> currency,
  Value<double> initialBalance,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> sortOrder,
  Value<double?> creditLimit,
  Value<int?> billingDay,
  Value<int?> paymentDueDay,
  Value<String?> bankName,
  Value<String?> cardLastFour,
  Value<String?> note,
  Value<String?> syncId,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<int> ledgerId,
  Value<String> name,
  Value<String> type,
  Value<String> currency,
  Value<double> initialBalance,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> sortOrder,
  Value<double?> creditLimit,
  Value<int?> billingDay,
  Value<int?> paymentDueDay,
  Value<String?> bankName,
  Value<String?> cardLastFour,
  Value<String?> note,
  Value<String?> syncId,
});

class $$AccountsTableFilterComposer
    extends Composer<_$BeeDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankName => $composableBuilder(
      column: $table.bankName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$AccountsTableOrderingComposer
    extends Composer<_$BeeDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankName => $composableBuilder(
      column: $table.bankName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => column);

  GeneratedColumn<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => column);

  GeneratedColumn<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => column);

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$AccountsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$BeeDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()> {
  $$AccountsTableTableManager(_$BeeDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<double> initialBalance = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<String?> bankName = const Value.absent(),
            Value<String?> cardLastFour = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              AccountsCompanion(
            id: id,
            ledgerId: ledgerId,
            name: name,
            type: type,
            currency: currency,
            initialBalance: initialBalance,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            creditLimit: creditLimit,
            billingDay: billingDay,
            paymentDueDay: paymentDueDay,
            bankName: bankName,
            cardLastFour: cardLastFour,
            note: note,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ledgerId,
            required String name,
            Value<String> type = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<double> initialBalance = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<String?> bankName = const Value.absent(),
            Value<String?> cardLastFour = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              AccountsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            name: name,
            type: type,
            currency: currency,
            initialBalance: initialBalance,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            creditLimit: creditLimit,
            billingDay: billingDay,
            paymentDueDay: paymentDueDay,
            bankName: bankName,
            cardLastFour: cardLastFour,
            note: note,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$BeeDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()>;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
  required String kind,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int?> parentId,
  Value<int> level,
  Value<String> iconType,
  Value<String?> customIconPath,
  Value<String?> communityIconId,
  Value<String?> syncId,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> kind,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int?> parentId,
  Value<int> level,
  Value<String> iconType,
  Value<String?> customIconPath,
  Value<String?> communityIconId,
  Value<String?> syncId,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$BeeDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconType => $composableBuilder(
      column: $table.iconType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customIconPath => $composableBuilder(
      column: $table.customIconPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get communityIconId => $composableBuilder(
      column: $table.communityIconId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$BeeDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconType => $composableBuilder(
      column: $table.iconType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customIconPath => $composableBuilder(
      column: $table.customIconPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get communityIconId => $composableBuilder(
      column: $table.communityIconId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
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

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get iconType =>
      $composableBuilder(column: $table.iconType, builder: (column) => column);

  GeneratedColumn<String> get customIconPath => $composableBuilder(
      column: $table.customIconPath, builder: (column) => column);

  GeneratedColumn<String> get communityIconId => $composableBuilder(
      column: $table.communityIconId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$BeeDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()> {
  $$CategoriesTableTableManager(_$BeeDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> icon = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<String> iconType = const Value.absent(),
            Value<String?> customIconPath = const Value.absent(),
            Value<String?> communityIconId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            name: name,
            kind: kind,
            icon: icon,
            sortOrder: sortOrder,
            parentId: parentId,
            level: level,
            iconType: iconType,
            customIconPath: customIconPath,
            communityIconId: communityIconId,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String kind,
            Value<String?> icon = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<String> iconType = const Value.absent(),
            Value<String?> customIconPath = const Value.absent(),
            Value<String?> communityIconId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            id: id,
            name: name,
            kind: kind,
            icon: icon,
            sortOrder: sortOrder,
            parentId: parentId,
            level: level,
            iconType: iconType,
            customIconPath: customIconPath,
            communityIconId: communityIconId,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$BeeDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  required int ledgerId,
  required String type,
  required double amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<DateTime> happenedAt,
  Value<String?> note,
  Value<int?> recurringId,
  Value<String?> syncId,
  Value<String?> createdByUserId,
  Value<String?> lastEditedByUserId,
  Value<String?> categorySyncIdOverride,
  Value<String?> accountSyncIdOverride,
  Value<String?> toAccountSyncIdOverride,
  Value<String?> tagSyncIdsOverride,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  Value<int> ledgerId,
  Value<String> type,
  Value<double> amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<DateTime> happenedAt,
  Value<String?> note,
  Value<int?> recurringId,
  Value<String?> syncId,
  Value<String?> createdByUserId,
  Value<String?> lastEditedByUserId,
  Value<String?> categorySyncIdOverride,
  Value<String?> accountSyncIdOverride,
  Value<String?> toAccountSyncIdOverride,
  Value<String?> tagSyncIdsOverride,
});

class $$TransactionsTableFilterComposer
    extends Composer<_$BeeDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recurringId => $composableBuilder(
      column: $table.recurringId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastEditedByUserId => $composableBuilder(
      column: $table.lastEditedByUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categorySyncIdOverride => $composableBuilder(
      column: $table.categorySyncIdOverride,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountSyncIdOverride => $composableBuilder(
      column: $table.accountSyncIdOverride,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toAccountSyncIdOverride => $composableBuilder(
      column: $table.toAccountSyncIdOverride,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagSyncIdsOverride => $composableBuilder(
      column: $table.tagSyncIdsOverride,
      builder: (column) => ColumnFilters(column));
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$BeeDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recurringId => $composableBuilder(
      column: $table.recurringId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastEditedByUserId => $composableBuilder(
      column: $table.lastEditedByUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categorySyncIdOverride => $composableBuilder(
      column: $table.categorySyncIdOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountSyncIdOverride => $composableBuilder(
      column: $table.accountSyncIdOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toAccountSyncIdOverride => $composableBuilder(
      column: $table.toAccountSyncIdOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagSyncIdsOverride => $composableBuilder(
      column: $table.tagSyncIdsOverride,
      builder: (column) => ColumnOrderings(column));
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => column);

  GeneratedColumn<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get recurringId => $composableBuilder(
      column: $table.recurringId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId, builder: (column) => column);

  GeneratedColumn<String> get lastEditedByUserId => $composableBuilder(
      column: $table.lastEditedByUserId, builder: (column) => column);

  GeneratedColumn<String> get categorySyncIdOverride => $composableBuilder(
      column: $table.categorySyncIdOverride, builder: (column) => column);

  GeneratedColumn<String> get accountSyncIdOverride => $composableBuilder(
      column: $table.accountSyncIdOverride, builder: (column) => column);

  GeneratedColumn<String> get toAccountSyncIdOverride => $composableBuilder(
      column: $table.toAccountSyncIdOverride, builder: (column) => column);

  GeneratedColumn<String> get tagSyncIdsOverride => $composableBuilder(
      column: $table.tagSyncIdsOverride, builder: (column) => column);
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$BeeDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()> {
  $$TransactionsTableTableManager(_$BeeDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<DateTime> happenedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int?> recurringId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<String?> createdByUserId = const Value.absent(),
            Value<String?> lastEditedByUserId = const Value.absent(),
            Value<String?> categorySyncIdOverride = const Value.absent(),
            Value<String?> accountSyncIdOverride = const Value.absent(),
            Value<String?> toAccountSyncIdOverride = const Value.absent(),
            Value<String?> tagSyncIdsOverride = const Value.absent(),
          }) =>
              TransactionsCompanion(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            happenedAt: happenedAt,
            note: note,
            recurringId: recurringId,
            syncId: syncId,
            createdByUserId: createdByUserId,
            lastEditedByUserId: lastEditedByUserId,
            categorySyncIdOverride: categorySyncIdOverride,
            accountSyncIdOverride: accountSyncIdOverride,
            toAccountSyncIdOverride: toAccountSyncIdOverride,
            tagSyncIdsOverride: tagSyncIdsOverride,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ledgerId,
            required String type,
            required double amount,
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<DateTime> happenedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int?> recurringId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<String?> createdByUserId = const Value.absent(),
            Value<String?> lastEditedByUserId = const Value.absent(),
            Value<String?> categorySyncIdOverride = const Value.absent(),
            Value<String?> accountSyncIdOverride = const Value.absent(),
            Value<String?> toAccountSyncIdOverride = const Value.absent(),
            Value<String?> tagSyncIdsOverride = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            happenedAt: happenedAt,
            note: note,
            recurringId: recurringId,
            syncId: syncId,
            createdByUserId: createdByUserId,
            lastEditedByUserId: lastEditedByUserId,
            categorySyncIdOverride: categorySyncIdOverride,
            accountSyncIdOverride: accountSyncIdOverride,
            toAccountSyncIdOverride: toAccountSyncIdOverride,
            tagSyncIdsOverride: tagSyncIdsOverride,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$BeeDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()>;
typedef $$RecurringTransactionsTableCreateCompanionBuilder
    = RecurringTransactionsCompanion Function({
  Value<int> id,
  required int ledgerId,
  required String type,
  required double amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<String?> note,
  required String frequency,
  Value<int> interval,
  Value<int?> dayOfMonth,
  Value<int?> dayOfWeek,
  Value<int?> monthOfYear,
  required DateTime startDate,
  Value<DateTime?> endDate,
  Value<DateTime?> lastGeneratedDate,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$RecurringTransactionsTableUpdateCompanionBuilder
    = RecurringTransactionsCompanion Function({
  Value<int> id,
  Value<int> ledgerId,
  Value<String> type,
  Value<double> amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<String?> note,
  Value<String> frequency,
  Value<int> interval,
  Value<int?> dayOfMonth,
  Value<int?> dayOfWeek,
  Value<int?> monthOfYear,
  Value<DateTime> startDate,
  Value<DateTime?> endDate,
  Value<DateTime?> lastGeneratedDate,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$RecurringTransactionsTableFilterComposer
    extends Composer<_$BeeDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get frequency => $composableBuilder(
      column: $table.frequency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
      column: $table.dayOfMonth, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
      column: $table.dayOfWeek, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get monthOfYear => $composableBuilder(
      column: $table.monthOfYear, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastGeneratedDate => $composableBuilder(
      column: $table.lastGeneratedDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$RecurringTransactionsTableOrderingComposer
    extends Composer<_$BeeDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get frequency => $composableBuilder(
      column: $table.frequency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
      column: $table.dayOfMonth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
      column: $table.dayOfWeek, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get monthOfYear => $composableBuilder(
      column: $table.monthOfYear, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastGeneratedDate => $composableBuilder(
      column: $table.lastGeneratedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecurringTransactionsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
      column: $table.dayOfMonth, builder: (column) => column);

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<int> get monthOfYear => $composableBuilder(
      column: $table.monthOfYear, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get lastGeneratedDate => $composableBuilder(
      column: $table.lastGeneratedDate, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecurringTransactionsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $RecurringTransactionsTable,
    RecurringTransaction,
    $$RecurringTransactionsTableFilterComposer,
    $$RecurringTransactionsTableOrderingComposer,
    $$RecurringTransactionsTableAnnotationComposer,
    $$RecurringTransactionsTableCreateCompanionBuilder,
    $$RecurringTransactionsTableUpdateCompanionBuilder,
    (
      RecurringTransaction,
      BaseReferences<_$BeeDatabase, $RecurringTransactionsTable,
          RecurringTransaction>
    ),
    RecurringTransaction,
    PrefetchHooks Function()> {
  $$RecurringTransactionsTableTableManager(
      _$BeeDatabase db, $RecurringTransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringTransactionsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringTransactionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringTransactionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> frequency = const Value.absent(),
            Value<int> interval = const Value.absent(),
            Value<int?> dayOfMonth = const Value.absent(),
            Value<int?> dayOfWeek = const Value.absent(),
            Value<int?> monthOfYear = const Value.absent(),
            Value<DateTime> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<DateTime?> lastGeneratedDate = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              RecurringTransactionsCompanion(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            note: note,
            frequency: frequency,
            interval: interval,
            dayOfMonth: dayOfMonth,
            dayOfWeek: dayOfWeek,
            monthOfYear: monthOfYear,
            startDate: startDate,
            endDate: endDate,
            lastGeneratedDate: lastGeneratedDate,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ledgerId,
            required String type,
            required double amount,
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required String frequency,
            Value<int> interval = const Value.absent(),
            Value<int?> dayOfMonth = const Value.absent(),
            Value<int?> dayOfWeek = const Value.absent(),
            Value<int?> monthOfYear = const Value.absent(),
            required DateTime startDate,
            Value<DateTime?> endDate = const Value.absent(),
            Value<DateTime?> lastGeneratedDate = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              RecurringTransactionsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            note: note,
            frequency: frequency,
            interval: interval,
            dayOfMonth: dayOfMonth,
            dayOfWeek: dayOfWeek,
            monthOfYear: monthOfYear,
            startDate: startDate,
            endDate: endDate,
            lastGeneratedDate: lastGeneratedDate,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecurringTransactionsTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $RecurringTransactionsTable,
        RecurringTransaction,
        $$RecurringTransactionsTableFilterComposer,
        $$RecurringTransactionsTableOrderingComposer,
        $$RecurringTransactionsTableAnnotationComposer,
        $$RecurringTransactionsTableCreateCompanionBuilder,
        $$RecurringTransactionsTableUpdateCompanionBuilder,
        (
          RecurringTransaction,
          BaseReferences<_$BeeDatabase, $RecurringTransactionsTable,
              RecurringTransaction>
        ),
        RecurringTransaction,
        PrefetchHooks Function()>;
typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> ledgerId,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> ledgerId,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$ConversationsTableFilterComposer
    extends Composer<_$BeeDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$BeeDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$BeeDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()> {
  $$ConversationsTableTableManager(_$BeeDatabase db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> ledgerId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              ConversationsCompanion(
            id: id,
            ledgerId: ledgerId,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> ledgerId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$BeeDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required int conversationId,
  required String role,
  required String content,
  required String messageType,
  Value<String?> metadata,
  Value<int?> transactionId,
  Value<DateTime> createdAt,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int> conversationId,
  Value<String> role,
  Value<String> content,
  Value<String> messageType,
  Value<String?> metadata,
  Value<int?> transactionId,
  Value<DateTime> createdAt,
});

class $$MessagesTableFilterComposer
    extends Composer<_$BeeDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$BeeDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$BeeDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$BeeDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> conversationId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            messageType: messageType,
            metadata: metadata,
            transactionId: transactionId,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int conversationId,
            required String role,
            required String content,
            required String messageType,
            Value<String?> metadata = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            messageType: messageType,
            metadata: metadata,
            transactionId: transactionId,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$BeeDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()>;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> color,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<String?> syncId,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> color,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<String?> syncId,
});

class $$TagsTableFilterComposer extends Composer<_$BeeDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$TagsTableOrderingComposer extends Composer<_$BeeDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$TagsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
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

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$TagsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$BeeDatabase, $TagsTable, Tag>),
    Tag,
    PrefetchHooks Function()> {
  $$TagsTableTableManager(_$BeeDatabase db, $TagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              TagsCompanion(
            id: id,
            name: name,
            color: color,
            sortOrder: sortOrder,
            createdAt: createdAt,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> color = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              TagsCompanion.insert(
            id: id,
            name: name,
            color: color,
            sortOrder: sortOrder,
            createdAt: createdAt,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TagsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$BeeDatabase, $TagsTable, Tag>),
    Tag,
    PrefetchHooks Function()>;
typedef $$TransactionTagsTableCreateCompanionBuilder = TransactionTagsCompanion
    Function({
  Value<int> id,
  required int transactionId,
  required int tagId,
});
typedef $$TransactionTagsTableUpdateCompanionBuilder = TransactionTagsCompanion
    Function({
  Value<int> id,
  Value<int> transactionId,
  Value<int> tagId,
});

class $$TransactionTagsTableFilterComposer
    extends Composer<_$BeeDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$TransactionTagsTableOrderingComposer
    extends Composer<_$BeeDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$TransactionTagsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<int> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$TransactionTagsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TransactionTagsTable,
    TransactionTag,
    $$TransactionTagsTableFilterComposer,
    $$TransactionTagsTableOrderingComposer,
    $$TransactionTagsTableAnnotationComposer,
    $$TransactionTagsTableCreateCompanionBuilder,
    $$TransactionTagsTableUpdateCompanionBuilder,
    (
      TransactionTag,
      BaseReferences<_$BeeDatabase, $TransactionTagsTable, TransactionTag>
    ),
    TransactionTag,
    PrefetchHooks Function()> {
  $$TransactionTagsTableTableManager(
      _$BeeDatabase db, $TransactionTagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> transactionId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
          }) =>
              TransactionTagsCompanion(
            id: id,
            transactionId: transactionId,
            tagId: tagId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int transactionId,
            required int tagId,
          }) =>
              TransactionTagsCompanion.insert(
            id: id,
            transactionId: transactionId,
            tagId: tagId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionTagsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $TransactionTagsTable,
    TransactionTag,
    $$TransactionTagsTableFilterComposer,
    $$TransactionTagsTableOrderingComposer,
    $$TransactionTagsTableAnnotationComposer,
    $$TransactionTagsTableCreateCompanionBuilder,
    $$TransactionTagsTableUpdateCompanionBuilder,
    (
      TransactionTag,
      BaseReferences<_$BeeDatabase, $TransactionTagsTable, TransactionTag>
    ),
    TransactionTag,
    PrefetchHooks Function()>;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  Value<String?> syncId,
  required int ledgerId,
  Value<String> type,
  Value<int?> categoryId,
  required double amount,
  Value<String> period,
  Value<int> startDay,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  Value<String?> syncId,
  Value<int> ledgerId,
  Value<String> type,
  Value<int?> categoryId,
  Value<double> amount,
  Value<String> period,
  Value<int> startDay,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$BeeDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startDay => $composableBuilder(
      column: $table.startDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$BeeDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startDay => $composableBuilder(
      column: $table.startDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get startDay =>
      $composableBuilder(column: $table.startDay, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BudgetsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$BeeDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()> {
  $$BudgetsTableTableManager(_$BeeDatabase db, $BudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> period = const Value.absent(),
            Value<int> startDay = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BudgetsCompanion(
            id: id,
            syncId: syncId,
            ledgerId: ledgerId,
            type: type,
            categoryId: categoryId,
            amount: amount,
            period: period,
            startDay: startDay,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            required int ledgerId,
            Value<String> type = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            required double amount,
            Value<String> period = const Value.absent(),
            Value<int> startDay = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BudgetsCompanion.insert(
            id: id,
            syncId: syncId,
            ledgerId: ledgerId,
            type: type,
            categoryId: categoryId,
            amount: amount,
            period: period,
            startDay: startDay,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BudgetsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$BeeDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()>;
typedef $$TransactionAttachmentsTableCreateCompanionBuilder
    = TransactionAttachmentsCompanion Function({
  Value<int> id,
  required int transactionId,
  required String fileName,
  Value<String?> originalName,
  Value<int?> fileSize,
  Value<int?> width,
  Value<int?> height,
  Value<int> sortOrder,
  Value<String?> cloudFileId,
  Value<String?> cloudSha256,
  Value<DateTime> createdAt,
});
typedef $$TransactionAttachmentsTableUpdateCompanionBuilder
    = TransactionAttachmentsCompanion Function({
  Value<int> id,
  Value<int> transactionId,
  Value<String> fileName,
  Value<String?> originalName,
  Value<int?> fileSize,
  Value<int?> width,
  Value<int?> height,
  Value<int> sortOrder,
  Value<String?> cloudFileId,
  Value<String?> cloudSha256,
  Value<DateTime> createdAt,
});

class $$TransactionAttachmentsTableFilterComposer
    extends Composer<_$BeeDatabase, $TransactionAttachmentsTable> {
  $$TransactionAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalName => $composableBuilder(
      column: $table.originalName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cloudFileId => $composableBuilder(
      column: $table.cloudFileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cloudSha256 => $composableBuilder(
      column: $table.cloudSha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$TransactionAttachmentsTableOrderingComposer
    extends Composer<_$BeeDatabase, $TransactionAttachmentsTable> {
  $$TransactionAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalName => $composableBuilder(
      column: $table.originalName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cloudFileId => $composableBuilder(
      column: $table.cloudFileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cloudSha256 => $composableBuilder(
      column: $table.cloudSha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TransactionAttachmentsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TransactionAttachmentsTable> {
  $$TransactionAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get originalName => $composableBuilder(
      column: $table.originalName, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get cloudFileId => $composableBuilder(
      column: $table.cloudFileId, builder: (column) => column);

  GeneratedColumn<String> get cloudSha256 => $composableBuilder(
      column: $table.cloudSha256, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TransactionAttachmentsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TransactionAttachmentsTable,
    TransactionAttachment,
    $$TransactionAttachmentsTableFilterComposer,
    $$TransactionAttachmentsTableOrderingComposer,
    $$TransactionAttachmentsTableAnnotationComposer,
    $$TransactionAttachmentsTableCreateCompanionBuilder,
    $$TransactionAttachmentsTableUpdateCompanionBuilder,
    (
      TransactionAttachment,
      BaseReferences<_$BeeDatabase, $TransactionAttachmentsTable,
          TransactionAttachment>
    ),
    TransactionAttachment,
    PrefetchHooks Function()> {
  $$TransactionAttachmentsTableTableManager(
      _$BeeDatabase db, $TransactionAttachmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionAttachmentsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionAttachmentsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionAttachmentsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> transactionId = const Value.absent(),
            Value<String> fileName = const Value.absent(),
            Value<String?> originalName = const Value.absent(),
            Value<int?> fileSize = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> cloudFileId = const Value.absent(),
            Value<String?> cloudSha256 = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransactionAttachmentsCompanion(
            id: id,
            transactionId: transactionId,
            fileName: fileName,
            originalName: originalName,
            fileSize: fileSize,
            width: width,
            height: height,
            sortOrder: sortOrder,
            cloudFileId: cloudFileId,
            cloudSha256: cloudSha256,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int transactionId,
            required String fileName,
            Value<String?> originalName = const Value.absent(),
            Value<int?> fileSize = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> cloudFileId = const Value.absent(),
            Value<String?> cloudSha256 = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransactionAttachmentsCompanion.insert(
            id: id,
            transactionId: transactionId,
            fileName: fileName,
            originalName: originalName,
            fileSize: fileSize,
            width: width,
            height: height,
            sortOrder: sortOrder,
            cloudFileId: cloudFileId,
            cloudSha256: cloudSha256,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionAttachmentsTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $TransactionAttachmentsTable,
        TransactionAttachment,
        $$TransactionAttachmentsTableFilterComposer,
        $$TransactionAttachmentsTableOrderingComposer,
        $$TransactionAttachmentsTableAnnotationComposer,
        $$TransactionAttachmentsTableCreateCompanionBuilder,
        $$TransactionAttachmentsTableUpdateCompanionBuilder,
        (
          TransactionAttachment,
          BaseReferences<_$BeeDatabase, $TransactionAttachmentsTable,
              TransactionAttachment>
        ),
        TransactionAttachment,
        PrefetchHooks Function()>;
typedef $$LocalChangesTableCreateCompanionBuilder = LocalChangesCompanion
    Function({
  Value<int> id,
  required String entityType,
  required int entityId,
  required String entitySyncId,
  required int ledgerId,
  required String action,
  Value<String?> payloadJson,
  Value<DateTime> createdAt,
  Value<DateTime?> pushedAt,
});
typedef $$LocalChangesTableUpdateCompanionBuilder = LocalChangesCompanion
    Function({
  Value<int> id,
  Value<String> entityType,
  Value<int> entityId,
  Value<String> entitySyncId,
  Value<int> ledgerId,
  Value<String> action,
  Value<String?> payloadJson,
  Value<DateTime> createdAt,
  Value<DateTime?> pushedAt,
});

class $$LocalChangesTableFilterComposer
    extends Composer<_$BeeDatabase, $LocalChangesTable> {
  $$LocalChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entitySyncId => $composableBuilder(
      column: $table.entitySyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get pushedAt => $composableBuilder(
      column: $table.pushedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalChangesTableOrderingComposer
    extends Composer<_$BeeDatabase, $LocalChangesTable> {
  $$LocalChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entitySyncId => $composableBuilder(
      column: $table.entitySyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get pushedAt => $composableBuilder(
      column: $table.pushedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalChangesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $LocalChangesTable> {
  $$LocalChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entitySyncId => $composableBuilder(
      column: $table.entitySyncId, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get pushedAt =>
      $composableBuilder(column: $table.pushedAt, builder: (column) => column);
}

class $$LocalChangesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $LocalChangesTable,
    LocalChange,
    $$LocalChangesTableFilterComposer,
    $$LocalChangesTableOrderingComposer,
    $$LocalChangesTableAnnotationComposer,
    $$LocalChangesTableCreateCompanionBuilder,
    $$LocalChangesTableUpdateCompanionBuilder,
    (
      LocalChange,
      BaseReferences<_$BeeDatabase, $LocalChangesTable, LocalChange>
    ),
    LocalChange,
    PrefetchHooks Function()> {
  $$LocalChangesTableTableManager(_$BeeDatabase db, $LocalChangesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<int> entityId = const Value.absent(),
            Value<String> entitySyncId = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String?> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> pushedAt = const Value.absent(),
          }) =>
              LocalChangesCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            entitySyncId: entitySyncId,
            ledgerId: ledgerId,
            action: action,
            payloadJson: payloadJson,
            createdAt: createdAt,
            pushedAt: pushedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityType,
            required int entityId,
            required String entitySyncId,
            required int ledgerId,
            required String action,
            Value<String?> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> pushedAt = const Value.absent(),
          }) =>
              LocalChangesCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            entitySyncId: entitySyncId,
            ledgerId: ledgerId,
            action: action,
            payloadJson: payloadJson,
            createdAt: createdAt,
            pushedAt: pushedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalChangesTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $LocalChangesTable,
    LocalChange,
    $$LocalChangesTableFilterComposer,
    $$LocalChangesTableOrderingComposer,
    $$LocalChangesTableAnnotationComposer,
    $$LocalChangesTableCreateCompanionBuilder,
    $$LocalChangesTableUpdateCompanionBuilder,
    (
      LocalChange,
      BaseReferences<_$BeeDatabase, $LocalChangesTable, LocalChange>
    ),
    LocalChange,
    PrefetchHooks Function()>;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  required String deviceId,
  Value<String> providerType,
  Value<int> serverCursor,
  Value<DateTime?> lastPushAt,
  Value<DateTime?> lastPullAt,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<String> deviceId,
  Value<String> providerType,
  Value<int> serverCursor,
  Value<DateTime?> lastPushAt,
  Value<DateTime?> lastPullAt,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$BeeDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerType => $composableBuilder(
      column: $table.providerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverCursor => $composableBuilder(
      column: $table.serverCursor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => ColumnFilters(column));
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$BeeDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerType => $composableBuilder(
      column: $table.providerType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverCursor => $composableBuilder(
      column: $table.serverCursor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$BeeDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get providerType => $composableBuilder(
      column: $table.providerType, builder: (column) => column);

  GeneratedColumn<int> get serverCursor => $composableBuilder(
      column: $table.serverCursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => column);
}

class $$SyncStateTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$BeeDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()> {
  $$SyncStateTableTableManager(_$BeeDatabase db, $SyncStateTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> providerType = const Value.absent(),
            Value<int> serverCursor = const Value.absent(),
            Value<DateTime?> lastPushAt = const Value.absent(),
            Value<DateTime?> lastPullAt = const Value.absent(),
          }) =>
              SyncStateCompanion(
            id: id,
            deviceId: deviceId,
            providerType: providerType,
            serverCursor: serverCursor,
            lastPushAt: lastPushAt,
            lastPullAt: lastPullAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String deviceId,
            Value<String> providerType = const Value.absent(),
            Value<int> serverCursor = const Value.absent(),
            Value<DateTime?> lastPushAt = const Value.absent(),
            Value<DateTime?> lastPullAt = const Value.absent(),
          }) =>
              SyncStateCompanion.insert(
            id: id,
            deviceId: deviceId,
            providerType: providerType,
            serverCursor: serverCursor,
            lastPushAt: lastPushAt,
            lastPullAt: lastPullAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStateTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$BeeDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()>;
typedef $$LedgerMembersTableCreateCompanionBuilder = LedgerMembersCompanion
    Function({
  required String ledgerSyncId,
  required String userId,
  Value<String?> email,
  Value<String?> displayName,
  Value<String?> avatarUrl,
  required String role,
  required DateTime joinedAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LedgerMembersTableUpdateCompanionBuilder = LedgerMembersCompanion
    Function({
  Value<String> ledgerSyncId,
  Value<String> userId,
  Value<String?> email,
  Value<String?> displayName,
  Value<String?> avatarUrl,
  Value<String> role,
  Value<DateTime> joinedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LedgerMembersTableFilterComposer
    extends Composer<_$BeeDatabase, $LedgerMembersTable> {
  $$LedgerMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
      column: $table.joinedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LedgerMembersTableOrderingComposer
    extends Composer<_$BeeDatabase, $LedgerMembersTable> {
  $$LedgerMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
      column: $table.joinedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LedgerMembersTableAnnotationComposer
    extends Composer<_$BeeDatabase, $LedgerMembersTable> {
  $$LedgerMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LedgerMembersTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $LedgerMembersTable,
    LedgerMember,
    $$LedgerMembersTableFilterComposer,
    $$LedgerMembersTableOrderingComposer,
    $$LedgerMembersTableAnnotationComposer,
    $$LedgerMembersTableCreateCompanionBuilder,
    $$LedgerMembersTableUpdateCompanionBuilder,
    (
      LedgerMember,
      BaseReferences<_$BeeDatabase, $LedgerMembersTable, LedgerMember>
    ),
    LedgerMember,
    PrefetchHooks Function()> {
  $$LedgerMembersTableTableManager(_$BeeDatabase db, $LedgerMembersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> ledgerSyncId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<DateTime> joinedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LedgerMembersCompanion(
            ledgerSyncId: ledgerSyncId,
            userId: userId,
            email: email,
            displayName: displayName,
            avatarUrl: avatarUrl,
            role: role,
            joinedAt: joinedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String ledgerSyncId,
            required String userId,
            Value<String?> email = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            required String role,
            required DateTime joinedAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LedgerMembersCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            userId: userId,
            email: email,
            displayName: displayName,
            avatarUrl: avatarUrl,
            role: role,
            joinedAt: joinedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LedgerMembersTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $LedgerMembersTable,
    LedgerMember,
    $$LedgerMembersTableFilterComposer,
    $$LedgerMembersTableOrderingComposer,
    $$LedgerMembersTableAnnotationComposer,
    $$LedgerMembersTableCreateCompanionBuilder,
    $$LedgerMembersTableUpdateCompanionBuilder,
    (
      LedgerMember,
      BaseReferences<_$BeeDatabase, $LedgerMembersTable, LedgerMember>
    ),
    LedgerMember,
    PrefetchHooks Function()>;
typedef $$SharedLedgerCategoriesTableCreateCompanionBuilder
    = SharedLedgerCategoriesCompanion Function({
  required String ledgerSyncId,
  required String syncId,
  required String name,
  required String kind,
  Value<String?> icon,
  Value<String> iconType,
  Value<String?> iconCloudFileId,
  Value<String?> iconCloudSha256,
  Value<String?> color,
  Value<int> sortOrder,
  Value<int> level,
  Value<String?> parentName,
  Value<String?> parentSyncId,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SharedLedgerCategoriesTableUpdateCompanionBuilder
    = SharedLedgerCategoriesCompanion Function({
  Value<String> ledgerSyncId,
  Value<String> syncId,
  Value<String> name,
  Value<String> kind,
  Value<String?> icon,
  Value<String> iconType,
  Value<String?> iconCloudFileId,
  Value<String?> iconCloudSha256,
  Value<String?> color,
  Value<int> sortOrder,
  Value<int> level,
  Value<String?> parentName,
  Value<String?> parentSyncId,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SharedLedgerCategoriesTableFilterComposer
    extends Composer<_$BeeDatabase, $SharedLedgerCategoriesTable> {
  $$SharedLedgerCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconType => $composableBuilder(
      column: $table.iconType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconCloudFileId => $composableBuilder(
      column: $table.iconCloudFileId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconCloudSha256 => $composableBuilder(
      column: $table.iconCloudSha256,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentName => $composableBuilder(
      column: $table.parentName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentSyncId => $composableBuilder(
      column: $table.parentSyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SharedLedgerCategoriesTableOrderingComposer
    extends Composer<_$BeeDatabase, $SharedLedgerCategoriesTable> {
  $$SharedLedgerCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconType => $composableBuilder(
      column: $table.iconType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconCloudFileId => $composableBuilder(
      column: $table.iconCloudFileId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconCloudSha256 => $composableBuilder(
      column: $table.iconCloudSha256,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentName => $composableBuilder(
      column: $table.parentName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentSyncId => $composableBuilder(
      column: $table.parentSyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SharedLedgerCategoriesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $SharedLedgerCategoriesTable> {
  $$SharedLedgerCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get iconType =>
      $composableBuilder(column: $table.iconType, builder: (column) => column);

  GeneratedColumn<String> get iconCloudFileId => $composableBuilder(
      column: $table.iconCloudFileId, builder: (column) => column);

  GeneratedColumn<String> get iconCloudSha256 => $composableBuilder(
      column: $table.iconCloudSha256, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get parentName => $composableBuilder(
      column: $table.parentName, builder: (column) => column);

  GeneratedColumn<String> get parentSyncId => $composableBuilder(
      column: $table.parentSyncId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedLedgerCategoriesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $SharedLedgerCategoriesTable,
    SharedLedgerCategory,
    $$SharedLedgerCategoriesTableFilterComposer,
    $$SharedLedgerCategoriesTableOrderingComposer,
    $$SharedLedgerCategoriesTableAnnotationComposer,
    $$SharedLedgerCategoriesTableCreateCompanionBuilder,
    $$SharedLedgerCategoriesTableUpdateCompanionBuilder,
    (
      SharedLedgerCategory,
      BaseReferences<_$BeeDatabase, $SharedLedgerCategoriesTable,
          SharedLedgerCategory>
    ),
    SharedLedgerCategory,
    PrefetchHooks Function()> {
  $$SharedLedgerCategoriesTableTableManager(
      _$BeeDatabase db, $SharedLedgerCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedLedgerCategoriesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedLedgerCategoriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedLedgerCategoriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> ledgerSyncId = const Value.absent(),
            Value<String> syncId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> icon = const Value.absent(),
            Value<String> iconType = const Value.absent(),
            Value<String?> iconCloudFileId = const Value.absent(),
            Value<String?> iconCloudSha256 = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<String?> parentName = const Value.absent(),
            Value<String?> parentSyncId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SharedLedgerCategoriesCompanion(
            ledgerSyncId: ledgerSyncId,
            syncId: syncId,
            name: name,
            kind: kind,
            icon: icon,
            iconType: iconType,
            iconCloudFileId: iconCloudFileId,
            iconCloudSha256: iconCloudSha256,
            color: color,
            sortOrder: sortOrder,
            level: level,
            parentName: parentName,
            parentSyncId: parentSyncId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String ledgerSyncId,
            required String syncId,
            required String name,
            required String kind,
            Value<String?> icon = const Value.absent(),
            Value<String> iconType = const Value.absent(),
            Value<String?> iconCloudFileId = const Value.absent(),
            Value<String?> iconCloudSha256 = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<String?> parentName = const Value.absent(),
            Value<String?> parentSyncId = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            syncId: syncId,
            name: name,
            kind: kind,
            icon: icon,
            iconType: iconType,
            iconCloudFileId: iconCloudFileId,
            iconCloudSha256: iconCloudSha256,
            color: color,
            sortOrder: sortOrder,
            level: level,
            parentName: parentName,
            parentSyncId: parentSyncId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SharedLedgerCategoriesTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $SharedLedgerCategoriesTable,
        SharedLedgerCategory,
        $$SharedLedgerCategoriesTableFilterComposer,
        $$SharedLedgerCategoriesTableOrderingComposer,
        $$SharedLedgerCategoriesTableAnnotationComposer,
        $$SharedLedgerCategoriesTableCreateCompanionBuilder,
        $$SharedLedgerCategoriesTableUpdateCompanionBuilder,
        (
          SharedLedgerCategory,
          BaseReferences<_$BeeDatabase, $SharedLedgerCategoriesTable,
              SharedLedgerCategory>
        ),
        SharedLedgerCategory,
        PrefetchHooks Function()>;
typedef $$SharedLedgerAccountsTableCreateCompanionBuilder
    = SharedLedgerAccountsCompanion Function({
  required String ledgerSyncId,
  required String syncId,
  required String name,
  Value<String> accountType,
  Value<String> currency,
  Value<String?> note,
  Value<double?> initialBalance,
  Value<double?> creditLimit,
  Value<int?> billingDay,
  Value<int?> paymentDueDay,
  Value<String?> bankName,
  Value<String?> cardLastFour,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SharedLedgerAccountsTableUpdateCompanionBuilder
    = SharedLedgerAccountsCompanion Function({
  Value<String> ledgerSyncId,
  Value<String> syncId,
  Value<String> name,
  Value<String> accountType,
  Value<String> currency,
  Value<String?> note,
  Value<double?> initialBalance,
  Value<double?> creditLimit,
  Value<int?> billingDay,
  Value<int?> paymentDueDay,
  Value<String?> bankName,
  Value<String?> cardLastFour,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SharedLedgerAccountsTableFilterComposer
    extends Composer<_$BeeDatabase, $SharedLedgerAccountsTable> {
  $$SharedLedgerAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountType => $composableBuilder(
      column: $table.accountType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankName => $composableBuilder(
      column: $table.bankName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SharedLedgerAccountsTableOrderingComposer
    extends Composer<_$BeeDatabase, $SharedLedgerAccountsTable> {
  $$SharedLedgerAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountType => $composableBuilder(
      column: $table.accountType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankName => $composableBuilder(
      column: $table.bankName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SharedLedgerAccountsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $SharedLedgerAccountsTable> {
  $$SharedLedgerAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get accountType => $composableBuilder(
      column: $table.accountType, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance, builder: (column) => column);

  GeneratedColumn<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => column);

  GeneratedColumn<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => column);

  GeneratedColumn<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => column);

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedLedgerAccountsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $SharedLedgerAccountsTable,
    SharedLedgerAccount,
    $$SharedLedgerAccountsTableFilterComposer,
    $$SharedLedgerAccountsTableOrderingComposer,
    $$SharedLedgerAccountsTableAnnotationComposer,
    $$SharedLedgerAccountsTableCreateCompanionBuilder,
    $$SharedLedgerAccountsTableUpdateCompanionBuilder,
    (
      SharedLedgerAccount,
      BaseReferences<_$BeeDatabase, $SharedLedgerAccountsTable,
          SharedLedgerAccount>
    ),
    SharedLedgerAccount,
    PrefetchHooks Function()> {
  $$SharedLedgerAccountsTableTableManager(
      _$BeeDatabase db, $SharedLedgerAccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedLedgerAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedLedgerAccountsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedLedgerAccountsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> ledgerSyncId = const Value.absent(),
            Value<String> syncId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> accountType = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<double?> initialBalance = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<String?> bankName = const Value.absent(),
            Value<String?> cardLastFour = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SharedLedgerAccountsCompanion(
            ledgerSyncId: ledgerSyncId,
            syncId: syncId,
            name: name,
            accountType: accountType,
            currency: currency,
            note: note,
            initialBalance: initialBalance,
            creditLimit: creditLimit,
            billingDay: billingDay,
            paymentDueDay: paymentDueDay,
            bankName: bankName,
            cardLastFour: cardLastFour,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String ledgerSyncId,
            required String syncId,
            required String name,
            Value<String> accountType = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<double?> initialBalance = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<String?> bankName = const Value.absent(),
            Value<String?> cardLastFour = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SharedLedgerAccountsCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            syncId: syncId,
            name: name,
            accountType: accountType,
            currency: currency,
            note: note,
            initialBalance: initialBalance,
            creditLimit: creditLimit,
            billingDay: billingDay,
            paymentDueDay: paymentDueDay,
            bankName: bankName,
            cardLastFour: cardLastFour,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SharedLedgerAccountsTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $SharedLedgerAccountsTable,
        SharedLedgerAccount,
        $$SharedLedgerAccountsTableFilterComposer,
        $$SharedLedgerAccountsTableOrderingComposer,
        $$SharedLedgerAccountsTableAnnotationComposer,
        $$SharedLedgerAccountsTableCreateCompanionBuilder,
        $$SharedLedgerAccountsTableUpdateCompanionBuilder,
        (
          SharedLedgerAccount,
          BaseReferences<_$BeeDatabase, $SharedLedgerAccountsTable,
              SharedLedgerAccount>
        ),
        SharedLedgerAccount,
        PrefetchHooks Function()>;
typedef $$SharedLedgerTagsTableCreateCompanionBuilder
    = SharedLedgerTagsCompanion Function({
  required String ledgerSyncId,
  required String syncId,
  required String name,
  Value<String?> color,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SharedLedgerTagsTableUpdateCompanionBuilder
    = SharedLedgerTagsCompanion Function({
  Value<String> ledgerSyncId,
  Value<String> syncId,
  Value<String> name,
  Value<String?> color,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SharedLedgerTagsTableFilterComposer
    extends Composer<_$BeeDatabase, $SharedLedgerTagsTable> {
  $$SharedLedgerTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SharedLedgerTagsTableOrderingComposer
    extends Composer<_$BeeDatabase, $SharedLedgerTagsTable> {
  $$SharedLedgerTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SharedLedgerTagsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $SharedLedgerTagsTable> {
  $$SharedLedgerTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ledgerSyncId => $composableBuilder(
      column: $table.ledgerSyncId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedLedgerTagsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $SharedLedgerTagsTable,
    SharedLedgerTag,
    $$SharedLedgerTagsTableFilterComposer,
    $$SharedLedgerTagsTableOrderingComposer,
    $$SharedLedgerTagsTableAnnotationComposer,
    $$SharedLedgerTagsTableCreateCompanionBuilder,
    $$SharedLedgerTagsTableUpdateCompanionBuilder,
    (
      SharedLedgerTag,
      BaseReferences<_$BeeDatabase, $SharedLedgerTagsTable, SharedLedgerTag>
    ),
    SharedLedgerTag,
    PrefetchHooks Function()> {
  $$SharedLedgerTagsTableTableManager(
      _$BeeDatabase db, $SharedLedgerTagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedLedgerTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharedLedgerTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharedLedgerTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> ledgerSyncId = const Value.absent(),
            Value<String> syncId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SharedLedgerTagsCompanion(
            ledgerSyncId: ledgerSyncId,
            syncId: syncId,
            name: name,
            color: color,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String ledgerSyncId,
            required String syncId,
            required String name,
            Value<String?> color = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SharedLedgerTagsCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            syncId: syncId,
            name: name,
            color: color,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SharedLedgerTagsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $SharedLedgerTagsTable,
    SharedLedgerTag,
    $$SharedLedgerTagsTableFilterComposer,
    $$SharedLedgerTagsTableOrderingComposer,
    $$SharedLedgerTagsTableAnnotationComposer,
    $$SharedLedgerTagsTableCreateCompanionBuilder,
    $$SharedLedgerTagsTableUpdateCompanionBuilder,
    (
      SharedLedgerTag,
      BaseReferences<_$BeeDatabase, $SharedLedgerTagsTable, SharedLedgerTag>
    ),
    SharedLedgerTag,
    PrefetchHooks Function()>;
typedef $$TransactionTagOverridesTableCreateCompanionBuilder
    = TransactionTagOverridesCompanion Function({
  required String transactionSyncId,
  required String tagSyncId,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$TransactionTagOverridesTableUpdateCompanionBuilder
    = TransactionTagOverridesCompanion Function({
  Value<String> transactionSyncId,
  Value<String> tagSyncId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$TransactionTagOverridesTableFilterComposer
    extends Composer<_$BeeDatabase, $TransactionTagOverridesTable> {
  $$TransactionTagOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transactionSyncId => $composableBuilder(
      column: $table.transactionSyncId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagSyncId => $composableBuilder(
      column: $table.tagSyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$TransactionTagOverridesTableOrderingComposer
    extends Composer<_$BeeDatabase, $TransactionTagOverridesTable> {
  $$TransactionTagOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transactionSyncId => $composableBuilder(
      column: $table.transactionSyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagSyncId => $composableBuilder(
      column: $table.tagSyncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TransactionTagOverridesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TransactionTagOverridesTable> {
  $$TransactionTagOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transactionSyncId => $composableBuilder(
      column: $table.transactionSyncId, builder: (column) => column);

  GeneratedColumn<String> get tagSyncId =>
      $composableBuilder(column: $table.tagSyncId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TransactionTagOverridesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TransactionTagOverridesTable,
    TransactionTagOverride,
    $$TransactionTagOverridesTableFilterComposer,
    $$TransactionTagOverridesTableOrderingComposer,
    $$TransactionTagOverridesTableAnnotationComposer,
    $$TransactionTagOverridesTableCreateCompanionBuilder,
    $$TransactionTagOverridesTableUpdateCompanionBuilder,
    (
      TransactionTagOverride,
      BaseReferences<_$BeeDatabase, $TransactionTagOverridesTable,
          TransactionTagOverride>
    ),
    TransactionTagOverride,
    PrefetchHooks Function()> {
  $$TransactionTagOverridesTableTableManager(
      _$BeeDatabase db, $TransactionTagOverridesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionTagOverridesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionTagOverridesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionTagOverridesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> transactionSyncId = const Value.absent(),
            Value<String> tagSyncId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionTagOverridesCompanion(
            transactionSyncId: transactionSyncId,
            tagSyncId: tagSyncId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String transactionSyncId,
            required String tagSyncId,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionTagOverridesCompanion.insert(
            transactionSyncId: transactionSyncId,
            tagSyncId: tagSyncId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionTagOverridesTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $TransactionTagOverridesTable,
        TransactionTagOverride,
        $$TransactionTagOverridesTableFilterComposer,
        $$TransactionTagOverridesTableOrderingComposer,
        $$TransactionTagOverridesTableAnnotationComposer,
        $$TransactionTagOverridesTableCreateCompanionBuilder,
        $$TransactionTagOverridesTableUpdateCompanionBuilder,
        (
          TransactionTagOverride,
          BaseReferences<_$BeeDatabase, $TransactionTagOverridesTable,
              TransactionTagOverride>
        ),
        TransactionTagOverride,
        PrefetchHooks Function()>;

class $BeeDatabaseManager {
  final _$BeeDatabase _db;
  $BeeDatabaseManager(this._db);
  $$LedgersTableTableManager get ledgers =>
      $$LedgersTableTableManager(_db, _db.ledgers);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(_db, _db.recurringTransactions);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TransactionTagsTableTableManager get transactionTags =>
      $$TransactionTagsTableTableManager(_db, _db.transactionTags);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$TransactionAttachmentsTableTableManager get transactionAttachments =>
      $$TransactionAttachmentsTableTableManager(
          _db, _db.transactionAttachments);
  $$LocalChangesTableTableManager get localChanges =>
      $$LocalChangesTableTableManager(_db, _db.localChanges);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$LedgerMembersTableTableManager get ledgerMembers =>
      $$LedgerMembersTableTableManager(_db, _db.ledgerMembers);
  $$SharedLedgerCategoriesTableTableManager get sharedLedgerCategories =>
      $$SharedLedgerCategoriesTableTableManager(
          _db, _db.sharedLedgerCategories);
  $$SharedLedgerAccountsTableTableManager get sharedLedgerAccounts =>
      $$SharedLedgerAccountsTableTableManager(_db, _db.sharedLedgerAccounts);
  $$SharedLedgerTagsTableTableManager get sharedLedgerTags =>
      $$SharedLedgerTagsTableTableManager(_db, _db.sharedLedgerTags);
  $$TransactionTagOverridesTableTableManager get transactionTagOverrides =>
      $$TransactionTagOverridesTableTableManager(
          _db, _db.transactionTagOverrides);
}
