class ExchangeRate {
  final int? id;
  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final String lastUpdated; // 'YYYY-MM-DD' recomendado

  const ExchangeRate({
    this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.lastUpdated,
  });

  factory ExchangeRate.fromMap(Map<String, dynamic> m) => ExchangeRate(
    id: m['id'] as int?,
    baseCurrency: m['base_currency'] as String,
    targetCurrency: m['target_currency'] as String,
    rate: (m['rate'] as num).toDouble(),
    lastUpdated: m['last_updated'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'base_currency': baseCurrency,
    'target_currency': targetCurrency,
    'rate': rate,
    'last_updated': lastUpdated,
  };

  ExchangeRate copyWith({
    int? id,
    String? baseCurrency,
    String? targetCurrency,
    double? rate,
    String? lastUpdated,
  }) {
    return ExchangeRate(
      id: id ?? this.id,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      rate: rate ?? this.rate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
