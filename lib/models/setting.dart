class AppSettings {
  final int? id; // siempre 1
  final String mainCurrency;
  final String secondaryCurrency;
  final String firstDayOfWeek;   // 'monday' | 'sunday' | etc.
  final String firstDayOfMonth;  // '1st' ...
  final String defaultView;      // 'weekly' | 'monthly' ...
  final bool backupEnabled;
  final bool notifications;
  final String themeMode;        // 'system' | 'light' | 'dark'
  final String language;         // 'es' | 'en' ...
  final bool biometricEnabled;
  final String? pinCode;
  final bool autoUpdateRates;
  final int rateUpdateIntervalDays;

  const AppSettings({
    this.id,
    required this.mainCurrency,
    this.secondaryCurrency = 'USD',
    this.firstDayOfWeek = 'Monday',
    this.firstDayOfMonth = '1st',
    this.defaultView = 'weekly',
    this.backupEnabled = false,
    this.notifications = true,
    this.themeMode = 'system',
    this.language = 'es',
    this.biometricEnabled = false,
    this.pinCode,
    this.autoUpdateRates = true,
    this.rateUpdateIntervalDays = 30,
  });

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
    id: m['id'] as int?,
    mainCurrency: m['main_currency'] as String,
    secondaryCurrency: (m['secondary_currency'] ?? 'USD') as String,
    firstDayOfWeek: (m['first_day_of_week'] ?? 'Monday') as String,
    firstDayOfMonth: (m['first_day_of_month'] ?? '1st') as String,
    defaultView: (m['default_view'] ?? 'weekly') as String,
    backupEnabled: (m['backup_enabled'] as int? ?? 0) == 1,
    notifications: (m['notifications'] as int? ?? 1) == 1,
    themeMode: (m['theme_mode'] ?? 'system') as String,
    language: (m['language'] ?? 'es') as String,
    biometricEnabled: (m['biometric_enabled'] as int? ?? 0) == 1,
    pinCode: m['pin_code'] as String?,
    autoUpdateRates: (m['auto_update_rates'] as int? ?? 1) == 1,
    rateUpdateIntervalDays: (m['rate_update_interval_days'] as num?)?.toInt() ?? 30,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'main_currency': mainCurrency,
    'secondary_currency': secondaryCurrency,
    'first_day_of_week': firstDayOfWeek,
    'first_day_of_month': firstDayOfMonth,
    'default_view': defaultView,
    'backup_enabled': backupEnabled ? 1 : 0,
    'notifications': notifications ? 1 : 0,
    'theme_mode': themeMode,
    'language': language,
    'biometric_enabled': biometricEnabled ? 1 : 0,
    'pin_code': pinCode,
    'auto_update_rates': autoUpdateRates ? 1 : 0,
    'rate_update_interval_days': rateUpdateIntervalDays,
  };

  AppSettings copyWith({
    int? id,
    String? mainCurrency,
    String? secondaryCurrency,
    String? firstDayOfWeek,
    String? firstDayOfMonth,
    String? defaultView,
    bool? backupEnabled,
    bool? notifications,
    String? themeMode,
    String? language,
    bool? biometricEnabled,
    String? pinCode,
    bool? autoUpdateRates,
    int? rateUpdateIntervalDays,
  }) {
    return AppSettings(
      id: id ?? this.id,
      mainCurrency: mainCurrency ?? this.mainCurrency,
      secondaryCurrency: secondaryCurrency ?? this.secondaryCurrency,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      firstDayOfMonth: firstDayOfMonth ?? this.firstDayOfMonth,
      defaultView: defaultView ?? this.defaultView,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      notifications: notifications ?? this.notifications,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinCode: pinCode ?? this.pinCode,
      autoUpdateRates: autoUpdateRates ?? this.autoUpdateRates,
      rateUpdateIntervalDays: rateUpdateIntervalDays ?? this.rateUpdateIntervalDays,
    );
  }
}
