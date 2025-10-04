class ScheduledTransaction {
  final int? id;
  final int accountId;
  final int? linkedAccountId;
  final String type;      // 'income' | 'expense' | 'transfer'
  final double amount;
  final String currency;  // ej. 'DOP'
  final int? categoryId;
  final String startDate; // 'YYYY-MM-DD'
  final String frequency; // ej. 'monthly', 'weekly', 'daily', 'custom:RRULE'
  final String nextRun;   // 'YYYY-MM-DD'
  final String? note;

  const ScheduledTransaction({
    this.id,
    required this.accountId,
    this.linkedAccountId,
    required this.type,
    required this.amount,
    required this.currency,
    this.categoryId,
    required this.startDate,
    required this.frequency,
    required this.nextRun,
    this.note,
  });

  factory ScheduledTransaction.fromMap(Map<String, dynamic> m) => ScheduledTransaction(
    id: m['id'] as int?,
    accountId: (m['account_id'] as num).toInt(),
    linkedAccountId: m['linked_account_id'] as int?,
    type: m['type'] as String,
    amount: (m['amount'] as num).toDouble(),
    currency: m['currency'] as String,
    categoryId: m['category_id'] as int?,
    startDate: m['start_date'] as String,
    frequency: m['frequency'] as String,
    nextRun: m['next_run'] as String,
    note: m['note'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'account_id': accountId,
    'linked_account_id': linkedAccountId,
    'type': type,
    'amount': amount,
    'currency': currency,
    'category_id': categoryId,
    'start_date': startDate,
    'frequency': frequency,
    'next_run': nextRun,
    'note': note,
  };

  ScheduledTransaction copyWith({
    int? id,
    int? accountId,
    int? linkedAccountId,
    String? type,
    double? amount,
    String? currency,
    int? categoryId,
    String? startDate,
    String? frequency,
    String? nextRun,
    String? note,
  }) {
    return ScheduledTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      startDate: startDate ?? this.startDate,
      frequency: frequency ?? this.frequency,
      nextRun: nextRun ?? this.nextRun,
      note: note ?? this.note,
    );
  }
}
