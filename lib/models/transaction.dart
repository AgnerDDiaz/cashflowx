// lib/models/transaction.dart

class AppTransaction {
  static const String typeIncome = 'income';
  static const String typeExpense = 'expense';
  static const String typeTransfer = 'transfer';

  final int? id;

  // Core
  final int accountId;
  final int? linkedAccountId; // sólo en transfer
  final String type;          // income | expense | transfer
  final double amount;
  final String currency;
  final int? categoryId;      // null en transfer
  final String date;          // ISO 'YYYY-MM-DD'
  final String? note;

  // Vinculo con recurrente (v12)
  final int? scheduledId;     // NULL si NO proviene de una recurrente

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
    this.scheduledId, // nuevo
  });

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
    int? scheduledId, // nuevo
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
      scheduledId: scheduledId ?? this.scheduledId, // nuevo
    );
  }

  factory AppTransaction.fromMap(Map<String, dynamic> m) {
    return AppTransaction(
      id: m['id'] as int?,
      accountId: (m['account_id'] as num).toInt(),
      linkedAccountId: m['linked_account_id'] as int?,
      type: m['type'] as String,
      amount: (m['amount'] as num).toDouble(),
      currency: m['currency'] as String,
      categoryId: m['category_id'] as int?,
      date: m['date'] as String,
      note: m['note'] as String?,
      scheduledId: m['scheduled_id'] as int?, // nuevo
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      'linked_account_id': linkedAccountId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'category_id': categoryId,
      'date': date,
      'note': note,
      'scheduled_id': scheduledId, // nuevo
    };
  }
}
