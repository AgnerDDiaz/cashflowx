
class ScheduledTransaction {
  final int? id;

  // Core
  final int accountId;
  final int? linkedAccountId;        // Solo para transferencias
  final String type;                 // 'income' | 'expense' | 'transfer'
  final double amount;
  final String currency;             // Ej.: 'DOP'
  final int? categoryId;             // null en transferencias

  // Programación
  final String startDate;            // ISO 'YYYY-MM-DD'
  final String? endDate;             // ISO 'YYYY-MM-DD' | null
  final String frequency;            // 'weekly'|'biweekly'|'monthly'|'quarterly'|'semiannual'|'annual'
  final String nextRun;              // ISO 'YYYY-MM-DD' (próxima ejecución)

  // Estado y observabilidad
  final int isActive;                // 1 = activo, 0 = pausado
  final int failedCount;             // cantidad de fallos al ejecutar
  final String? lastError;           // último error si falló
  final String tz;                   // zona horaria base (ej. 'UTC')

  // Extra
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
    this.endDate,
    required this.frequency,
    required this.nextRun,
    this.isActive = 1,
    this.failedCount = 0,
    this.lastError,
    this.tz = 'UTC',
    this.note,
  });

  // --------- Helpers opcionales ----------
  bool get isPaused => isActive == 0;

  ScheduledTransaction copyWith({
    int? id,
    int? accountId,
    int? linkedAccountId,
    String? type,
    double? amount,
    String? currency,
    int? categoryId,
    String? startDate,
    String? endDate,
    String? frequency,
    String? nextRun,
    int? isActive,
    int? failedCount,
    String? lastError,
    String? tz,
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
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      nextRun: nextRun ?? this.nextRun,
      isActive: isActive ?? this.isActive,
      failedCount: failedCount ?? this.failedCount,
      lastError: lastError ?? this.lastError,
      tz: tz ?? this.tz,
      note: note ?? this.note,
    );
  }

  // --------- Map ↔ Model ----------
  factory ScheduledTransaction.fromMap(Map<String, dynamic> m) {
    return ScheduledTransaction(
      id: m['id'] as int?,
      accountId: (m['account_id'] as num).toInt(),
      linkedAccountId: m['linked_account_id'] as int?,
      type: m['type'] as String,
      amount: (m['amount'] as num).toDouble(),
      currency: m['currency'] as String,
      categoryId: m['category_id'] as int?,
      startDate: m['start_date'] as String,
      endDate: m['end_date'] as String?,
      frequency: m['frequency'] as String,
      nextRun: m['next_run'] as String,
      isActive: (m['is_active'] as num?)?.toInt() ?? 1,
      failedCount: (m['failed_count'] as num?)?.toInt() ?? 0,
      lastError: m['last_error'] as String?,
      tz: (m['tz'] as String?) ?? 'UTC',
      note: m['note'] as String?,
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
      'start_date': startDate,
      'end_date': endDate,
      'frequency': frequency,
      'next_run': nextRun,
      'is_active': isActive,
      'failed_count': failedCount,
      'last_error': lastError,
      'tz': tz,
      'note': note,
    };
  }
}
