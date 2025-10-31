class Account {
  final int? id;
  final String name;
  /// 'normal' | 'credit' | 'saving' | 'debt'
  final String type;

  /// Agrupador real (account_groups.id)
  final int? groupId;

  /// Saldo actual
  final double balance;

  /// 'DOP', 'USD', ...
  final String currency;

  /// 'default' | 'credit' | 'debit'
  final String balanceMode;

  /// Fechas relevantes
  final String? dueDate;    // p/ préstamos o pago
  final String? cutoffDate; // p/ tarjetas

  /// Límite de tarjeta (opcional)
  final double? maxCredit;

  /// Visibilidad
  final int visible;           // 1/0
  final int includeInBalance;  // 1/0

  const Account({
    this.id,
    required this.name,
    required this.type,
    required this.groupId,
    required this.balance,
    required this.currency,
    required this.balanceMode,
    this.dueDate,
    this.cutoffDate,
    this.maxCredit,
    this.visible = 1,
    this.includeInBalance = 1,
  });

  factory Account.fromMap(Map<String, dynamic> m) => Account(
    id: m['id'] as int?,
    name: (m['name'] ?? '') as String,
    type: (m['type'] ?? 'normal') as String,
    groupId: m['group_id'] as int?,
    balance: (m['balance'] as num?)?.toDouble() ?? 0.0,
    currency: (m['currency'] ?? 'DOP') as String,
    balanceMode: (m['balance_mode'] ?? 'default') as String,
    dueDate: m['due_date'] as String?,
    cutoffDate: m['cutoff_date'] as String?,
    maxCredit: (m['max_credit'] as num?)?.toDouble(),
    visible: (m['visible'] as int?) ?? 1,
    includeInBalance: (m['include_in_balance'] as int?) ?? 1,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type,
    'group_id': groupId,
    'balance': balance,
    'currency': currency,
    'balance_mode': balanceMode,
    'due_date': dueDate,
    'cutoff_date': cutoffDate,
    'max_credit': maxCredit,
    'visible': visible,
    'include_in_balance': includeInBalance,
  };

  bool get includeInBalanceBool => includeInBalance == 1;

  Account copyWith({
    int? id,
    String? name,
    String? type,
    int? groupId,
    double? balance,
    String? currency,
    String? balanceMode,
    String? dueDate,
    String? cutoffDate,
    double? maxCredit,
    int? visible,
    int? includeInBalance,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      groupId: groupId ?? this.groupId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      balanceMode: balanceMode ?? this.balanceMode,
      dueDate: dueDate ?? this.dueDate,
      cutoffDate: cutoffDate ?? this.cutoffDate,
      maxCredit: maxCredit ?? this.maxCredit,
      visible: visible ?? this.visible,
      includeInBalance: includeInBalance ?? this.includeInBalance,
    );
  }
}
