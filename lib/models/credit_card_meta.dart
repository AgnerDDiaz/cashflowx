class CreditCardMeta {
  final int accountId;
  final int? statementDay;     // día de corte (1–28)
  final int? dueDay;           // día de pago (1–28)
  final double statementDue;   // monto a pagar "Este ciclo"
  final double postStatement;  // consumos post-corte ("Próximo ciclo")
  final double? creditLimit;   // null si no definido

  const CreditCardMeta({
    required this.accountId,
    this.statementDay,
    this.dueDay,
    this.statementDue = 0.0,
    this.postStatement = 0.0,
    this.creditLimit,
  });

  factory CreditCardMeta.fromMap(Map<String, dynamic> m) => CreditCardMeta(
    accountId: m['account_id'] as int,
    statementDay: (m['statement_day'] as num?)?.toInt(),
    dueDay: (m['due_day'] as num?)?.toInt(),
    statementDue: (m['statement_due'] as num?)?.toDouble() ?? 0.0,
    postStatement: (m['post_statement'] as num?)?.toDouble() ?? 0.0,
    creditLimit: (m['credit_limit'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'account_id': accountId,
    'statement_day': statementDay,
    'due_day': dueDay,
    'statement_due': statementDue,
    'post_statement': postStatement,
    'credit_limit': creditLimit,
  };

  CreditCardMeta copyWith({
    int? accountId,
    int? statementDay,
    int? dueDay,
    double? statementDue,
    double? postStatement,
    double? creditLimit,
  }) => CreditCardMeta(
    accountId: accountId ?? this.accountId,
    statementDay: statementDay ?? this.statementDay,
    dueDay: dueDay ?? this.dueDay,
    statementDue: statementDue ?? this.statementDue,
    postStatement: postStatement ?? this.postStatement,
    creditLimit: creditLimit ?? this.creditLimit,
  );
}