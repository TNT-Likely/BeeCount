/// Signed balances remain the storage/sync contract. UI amounts are non-negative.
class CreditCardAmounts {
  final double balance;
  final double? limit;

  const CreditCardAmounts(this.balance, {this.limit});

  double get debt => balance < 0 ? -balance : 0;
  double get overpayment => balance > 0 ? balance : 0;
  double? get estimatedAvailable => limit == null || limit! <= 0
      ? null
      : (limit! + balance).clamp(0.0, double.infinity);
}
