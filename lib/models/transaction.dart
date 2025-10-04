class AppTransaction {
  // Tipos
  static const String typeIncome  = 'income';
  static const String typeExpense = 'expense';
  static const String typeTransfer= 'transfer';

  final int? id;
  final int accountId;         // cuenta origen
  final int? linkedAccountId;  // cuenta destino (solo transfer)
  final String type;           // income | expense | transfer
  final double amount;         // > 0
  final String currency;       // 'DOP', 'USD', ...
  final int? categoryId;       // NULL para transfer
  final String date;           // 'YYYY-MM-DD'
  final String? note;

  const AppTransaction({
    this.id,
    required this.accountId,
    this.linkedAccountId,
    required this.type,
    required this.amount,
    required this.currency,
    this.categoryId,
    required this.date,
    this.note,
  });

  bool get isTransfer => type == typeTransfer;

  AppTransaction copyWith({
    int? id,
    int? accountId,
    int? linkedAccountId,
    String? type,
    double? amount,
    String? currency,
    int? categoryId,
    String? date,
    String? note,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  factory AppTransaction.fromMap(Map<String, dynamic> m) => AppTransaction(
    id: m['id'] as int?,
    accountId: (m['account_id'] as num).toInt(),
    linkedAccountId: m['linked_account_id'] as int?,
    type: m['type'] as String,
    amount: (m['amount'] as num).toDouble(),
    currency: m['currency'] as String,
    categoryId: m['category_id'] as int?,
    date: m['date'] as String,
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
    'date': date,
    'note': note,
  };
}
