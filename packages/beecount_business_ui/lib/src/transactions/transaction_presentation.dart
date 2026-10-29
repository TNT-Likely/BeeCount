import 'package:flutter/material.dart';

class BeeTagData {
  const BeeTagData(this.id, this.label, this.color);
  final String id, label;
  final Color color;
}

enum BeeTransactionKind { expense, income, transfer }

/// Shared semantic palette. Reversing the user's color convention changes the
/// mapping without changing signs, amounts or transaction kinds.
Color beeTransactionColor(BuildContext context, BeeTransactionKind kind,
    {bool incomeIsRed = true}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final mapped = incomeIsRed
      ? kind
      : switch (kind) {
          BeeTransactionKind.expense => BeeTransactionKind.income,
          BeeTransactionKind.income => BeeTransactionKind.expense,
          BeeTransactionKind.transfer => BeeTransactionKind.transfer,
        };
  return switch (mapped) {
    BeeTransactionKind.expense =>
      dark ? const Color(0xff79c8ad) : const Color(0xff25856d),
    BeeTransactionKind.income =>
      dark ? const Color(0xffe49a8d) : const Color(0xffbd5d50),
    BeeTransactionKind.transfer =>
      Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

/// Mirrors the existing transaction row: full date overrides the time switch;
/// a time-only row suppresses exact midnight, but keeps non-zero seconds.
String? formatBeeTransactionTimestamp(DateTime? value,
    {bool showTime = false, bool showFullDate = false}) {
  if (value == null) return null;
  String pad(int n) => n.toString().padLeft(2, '0');
  if (showFullDate) {
    return '${value.year}-${pad(value.month)}-${pad(value.day)} ${pad(value.hour)}:${pad(value.minute)}';
  }
  if (!showTime ||
      (value.hour == 0 && value.minute == 0 && value.second == 0)) {
    return null;
  }
  return '${pad(value.hour)}:${pad(value.minute)}:${pad(value.second)}';
}
