import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'exchange_rate_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'cashflowx.db');

    return await openDatabase(
      path,
      version: 6, // NUEVA VERSIÓN para aplicar cambios
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      category TEXT NOT NULL,
      balance REAL NOT NULL,
      currency TEXT NOT NULL,
      interest_rate REAL DEFAULT 0,
      interest_period TEXT DEFAULT NULL,
      penalty_rate REAL DEFAULT 0,
      penalty_fixed REAL DEFAULT 0,
      due_date TEXT DEFAULT NULL,
      cutoff_date TEXT DEFAULT NULL,
      balance_mode TEXT NOT NULL CHECK (balance_mode IN ('debit', 'credit', 'default')) DEFAULT 'default',
      max_credit REAL DEFAULT NULL,
      visible INTEGER DEFAULT 1,
      include_in_balance INTEGER DEFAULT 1
    );
    ''');

    await db.execute('''
    CREATE TABLE exchange_rates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      base_currency TEXT NOT NULL,
      target_currency TEXT NOT NULL,
      rate REAL NOT NULL,
      last_updated TEXT NOT NULL
    );
    ''');

    await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
      parent_id INTEGER DEFAULT NULL,
      FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE
    );
    ''');

    await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      linked_account_id INTEGER,
      type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
      amount REAL NOT NULL CHECK (amount > 0),
      currency TEXT NOT NULL DEFAULT 'DOP', -- 👈 AÑADIMOS ESTE CAMPO
      category_id INTEGER DEFAULT NULL,
      date TEXT NOT NULL,
      note TEXT DEFAULT NULL,
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
      FOREIGN KEY (linked_account_id) REFERENCES accounts(id) ON DELETE CASCADE,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
      CHECK (type <> 'transfer' OR linked_account_id IS NOT NULL)
    );

    ''');

    await db.execute('''
    CREATE TABLE presupuestos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      categoria_id INTEGER NOT NULL,
      monto_maximo REAL NOT NULL,
      periodo TEXT NOT NULL,
      fecha_creacion TEXT NOT NULL,
     FOREIGN KEY (categoria_id) REFERENCES categories(id)
    );
    ''');
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        main_currency TEXT NOT NULL,
        secondary_currency TEXT DEFAULT 'USD',
        first_day_of_week TEXT DEFAULT 'Monday',
        first_day_of_month TEXT DEFAULT '1st',
        default_view TEXT DEFAULT 'weekly',
        backup_enabled INTEGER DEFAULT 0,
        notifications INTEGER DEFAULT 1,
        theme_mode TEXT DEFAULT 'system',
        language TEXT DEFAULT 'es',
        biometric_enabled INTEGER DEFAULT 0,
        pin_code TEXT DEFAULT NULL,
        auto_update_rates INTEGER DEFAULT 1,
        rate_update_interval_days INTEGER DEFAULT 30
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_exchange_rates_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        base_currency TEXT NOT NULL,
        target_currency TEXT NOT NULL,
        rate REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Insertar settings por defecto
    await db.insert('settings', {
      'main_currency': 'USD',
      'secondary_currency': 'DOP',
      'first_day_of_week': 'Monday',
      'first_day_of_month': '1st',
      'default_view': 'weekly',
      'backup_enabled': 0,
      'notifications': 1,
      'theme_mode': 'system',
      'language': 'es',
      'biometric_enabled': 0,
      'auto_update_rates': 1,
      'rate_update_interval_days': 30
    });

    await db.execute('''
      CREATE TABLE currency_names (
        code TEXT PRIMARY KEY,
        name TEXT
      );
    ''');


    await insertCategoriesAndSubcategories(db);
    await insertDefaultAccounts(db);
    await insertTestTransactions(db);
    await db.insert('currency_names', {'code': 'USD', 'name': 'United States Dollar'});
    await db.insert('currency_names', {'code': 'DOP', 'name': 'Dominican Peso'});
    await db.insert('currency_names', {'code': 'EUR', 'name': 'Euro'});
    await db.insert('currency_names', {'code': 'JPY', 'name': 'Japanese Yen'});


  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE settings ADD COLUMN secondary_currency TEXT DEFAULT 'USD';");
      await db.execute("ALTER TABLE settings ADD COLUMN theme_mode TEXT DEFAULT 'system';");
      await db.execute("ALTER TABLE settings ADD COLUMN language TEXT DEFAULT 'es';");
      await db.execute("ALTER TABLE settings ADD COLUMN biometric_enabled INTEGER DEFAULT 0;");
      await db.execute("ALTER TABLE settings ADD COLUMN pin_code TEXT DEFAULT NULL;");
      await db.execute("ALTER TABLE settings ADD COLUMN auto_update_rates INTEGER DEFAULT 1;");
      await db.execute("ALTER TABLE settings ADD COLUMN rate_update_interval_days INTEGER DEFAULT 30;");

      await db.execute('''
        CREATE TABLE custom_exchange_rates_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          base_currency TEXT NOT NULL,
          target_currency TEXT NOT NULL,
          rate REAL NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE currency_names (
          code TEXT PRIMARY KEY,
          name TEXT
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS currency_names (
          code TEXT PRIMARY KEY,
          name TEXT
        );
      ''');



    }
  }


  Future<void> insertDefaultAccounts(Database db) async {
    // 📦 Insertar Cuentas de Prueba Mejoradas
    List<Map<String, dynamic>> testAccounts = [
      {
        'name': 'Cuenta Banreservas',
        'type': 'normal',
        'category': 'Cuentas personales',
        'balance': 46.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 0,
        'visible': 0,
      },
      {
        'name': 'Cuenta Popular (carrito)',
        'type': 'normal',
        'category': 'Cuentas personales',
        'balance': 2260.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Cuenta BHD (SamTech)',
        'type': 'normal',
        'category': 'Cuentas del negocio',
        'balance': 13067.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Tarjeta gold Banreservas',
        'type': 'credit',
        'category': 'Tarjetas de crédito',
        'balance': 21324.55,
        'currency': 'DOP',
        'balance_mode': 'credit',
        'max_credit': 50000.0,
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Cuenta BHD (conjunta)',
        'type': 'credit',
        'category': 'Tarjetas de crédito',
        'balance': 365.00,
        'currency': 'DOP',
        'balance_mode': 'credit',
        'max_credit': 10000.0,
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Tarjeta de crédito personal',
        'type': 'credit',
        'category': 'Tarjetas de crédito',
        'balance': 409.00,
        'currency': 'DOP',
        'balance_mode': 'credit',
        'max_credit': 50000.0,
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Deuda a Eleanny',
        'type': 'debt',
        'category': 'Deudas',
        'balance': -5758.76,
        'currency': 'USD',
        'balance_mode': 'credit',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Ahorro en monedas',
        'type': 'saving',
        'category': 'Ahorros',
        'balance': 300.00,
        'currency': 'EUR',
        'balance_mode': 'debit',
        'interest_rate': 2.5,
        'interest_period': 'anual',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Fondo de emergencia',
        'type': 'saving',
        'category': 'Ahorros',
        'balance': 5044.00,
        'currency': 'DOP',
        'balance_mode': 'default',
        'interest_rate': 1.5,
        'interest_period': 'anual',
        'include_in_balance': 1,
        'visible': 1,
      },
    ];
    for (var acc in testAccounts) {
      await db.insert('accounts', acc);
    }

// 📦 Insertar tasas de cambio de prueba (si no lo has puesto ya)
    await db.insert('exchange_rates', {
      'base_currency': 'USD',
      'target_currency': 'DOP',
      'rate': 58.5,
      'last_updated': '2025-04-03',
    });
    await db.insert('exchange_rates', {
      'base_currency': 'EUR',
      'target_currency': 'DOP',
      'rate': 63.75,
      'last_updated': '2025-04-03',
    });
    await db.insert('exchange_rates', {
      'base_currency': 'GBP',
      'target_currency': 'DOP',
      'rate': 74.23,
      'last_updated': '2025-04-03',
    });

    await db.insert('exchange_rates', {
      'base_currency': 'CAD',
      'target_currency': 'DOP',
      'rate': 42.15,
      'last_updated': '2025-04-03',
    });

    await db.insert('exchange_rates', {
      'base_currency': 'JPY',
      'target_currency': 'DOP',
      'rate': 0.53,
      'last_updated': '2025-04-03',
    });

    await db.insert('exchange_rates', {
      'base_currency': 'MXN',
      'target_currency': 'DOP',
      'rate': 3.42,
      'last_updated': '2025-04-03',
    });

    await db.insert('exchange_rates', {
      'base_currency': 'CHF',
      'target_currency': 'DOP',
      'rate': 64.11,
      'last_updated': '2025-04-03',
    });




    // 📌 Insertar Transacciones de Prueba
    await insertTestTransactions(db);
  }

  /// 📌 **Función para Insertar Categorías y Subcategorías (Evita Duplicados)**
  Future<void> insertCategoriesAndSubcategories(Database db) async {
    // 🔹 Insertar categorías principales
    List<Map<String, dynamic>> defaultCategories = [
      {'name': 'Transporte', 'type': 'expense', 'parent_id': null},
      {'name': 'Comida', 'type': 'expense', 'parent_id': null},
      {'name': 'Hogar', 'type': 'expense', 'parent_id': null},
      {'name': 'Deudas', 'type': 'expense', 'parent_id': null},
      {'name': 'Salud', 'type': 'expense', 'parent_id': null},
      {'name': 'Sueldo', 'type': 'income', 'parent_id': null},
      {'name': 'Bono', 'type': 'income', 'parent_id': null},
    ];

    // 📌 Insertar las categorías principales
    for (var category in defaultCategories) {
      await db.insert(
        'categories',
        category,
        conflictAlgorithm: ConflictAlgorithm.ignore, // Evita duplicados
      );
    }

    // 🔹 Obtener IDs de las categorías principales para asignar subcategorías
    Future<int?> getCategoryId(String categoryName) async {
      List<Map<String, dynamic>> result = await db.query(
        'categories',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [categoryName],
      );
      return result.isNotEmpty ? result.first['id'] as int : null;
    }

    // 🔹 Insertar subcategorías (dependiendo de sus categorías principales)
    List<Map<String, dynamic>> subcategories = [
      {'name': 'Gasolina', 'type': 'expense', 'parent_id': await getCategoryId('Transporte')},
      {'name': 'Taxi/Uber', 'type': 'expense', 'parent_id': await getCategoryId('Transporte')},
      {'name': 'Pasajes', 'type': 'expense', 'parent_id': await getCategoryId('Transporte')},

      {'name': 'Comida Rápida', 'type': 'expense', 'parent_id': await getCategoryId('Comida')},
      {'name': 'Restaurante', 'type': 'expense', 'parent_id': await getCategoryId('Comida')},
      {'name': 'Supermercado', 'type': 'expense', 'parent_id': await getCategoryId('Comida')},

      {'name': 'Alquiler', 'type': 'expense', 'parent_id': await getCategoryId('Hogar')},
      {'name': 'Servicios (Luz, Agua, Internet)', 'type': 'expense', 'parent_id': await getCategoryId('Hogar')},
      {'name': 'Mantenimiento', 'type': 'expense', 'parent_id': await getCategoryId('Hogar')},

      {'name': 'Médico', 'type': 'expense', 'parent_id': await getCategoryId('Salud')},
      {'name': 'Medicinas', 'type': 'expense', 'parent_id': await getCategoryId('Salud')},
      {'name': 'Gimnasio', 'type': 'expense', 'parent_id': await getCategoryId('Salud')},

      {'name': 'Sueldo Base', 'type': 'income', 'parent_id': await getCategoryId('Sueldo')},
      {'name': 'Horas Extras', 'type': 'income', 'parent_id': await getCategoryId('Sueldo')},

      {'name': 'Bono Anual', 'type': 'income', 'parent_id': await getCategoryId('Bono')},
      {'name': 'Bono de Producción', 'type': 'income', 'parent_id': await getCategoryId('Bono')},
    ];

    // 📌 Insertar las subcategorías
    for (var subcategory in subcategories) {
      await db.insert(
        'categories',
        subcategory,
        conflictAlgorithm: ConflictAlgorithm.ignore, // Evita duplicados
      );
    }
  }


  /// 📌 **Función para Insertar Transacciones de Prueba**
  Future<void> insertTestTransactions(Database db) async {
    // 🔄 Buscar ID de categorías dinámicamente para evitar errores si el usuario las modificó
    Future<int?> getCategoryId(String categoryName) async {
      List<Map<String, dynamic>> result = await db.query(
        'categories',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [categoryName],
      );
      return result.isNotEmpty ? result.first['id'] as int : null;
    }

    List<Map<String, dynamic>> testTransactions = [
      {
        'account_id': 1,
        'type': 'expense',
        'amount': 200.0,
        'currency': 'DOP', // 👈 NUEVO
        'category_id': await getCategoryId('Comida'),
        'date': '2025-03-18',
        'note': 'Cena en restaurante'
      },
      {
        'account_id': 1,
        'type': 'expense',
        'amount': 100.0,
        'currency': 'DOP', // 👈 NUEVO
        'category_id': await getCategoryId('Transporte'),
        'date': '2025-03-18',
        'note': 'Taxi'
      },
      {
        'account_id': 2,
        'type': 'income',
        'amount': 10000.0,
        'currency': 'DOP', // 👈 NUEVO
        'category_id': await getCategoryId('Sueldo'),
        'date': '2025-03-17',
        'note': 'Salario mensual'
      },
      {
        'account_id': 3,
        'type': 'transfer',
        'amount': 2000.0,
        'currency': 'DOP', // 👈 NUEVO
        'category_id': null,
        'linked_account_id': 4, // Asegurar que tiene una cuenta destino
        'date': '2025-03-16',
        'note': 'Pago de tarjeta de crédito'
      },
      {
        'account_id': 4,
        'type': 'expense',
        'amount': 5000.0,
        'currency': 'DOP', // 👈 NUEVO
        'category_id': await getCategoryId('Deudas'),
        'date': '2025-03-15',
        'note': 'Pago parcial de deuda'
      },
    ];

    for (var transaction in testTransactions) {
        await db.insert('transactions', transaction);
    }
  }


// Métodos para las operaciones CRUD
  Future<int> addAccount(Map<String, dynamic> account) async {
    final db = await database;
    return await db.insert('accounts', account);
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return await db.query('accounts'); // Este ya trae balance_mode si existe en la tabla
  }


  Future<int> updateAccount(int id, Map<String, dynamic> updatedAccount) async {
    final db = await database;
    return await db.update(
      'accounts',
      updatedAccount,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getAccountBalance(int accountId) async {
    final db = await database;
    final result = await db.query(
      'accounts',
      columns: ['balance'],
      where: 'id = ?',
      whereArgs: [accountId],
    );

    if (result.isNotEmpty) {
      return result.first['balance'] as double;
    } else {
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionsByAccount(int accountId) async {
    final db = await database;

    final result = await db.query(
      'transactions',
      where: 'account_id = ? OR linked_account_id = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC',
    );

    return result;
  }



  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> addTransaction(Map<String, dynamic> transaction) async {
    final db = await database;

    final account = await db.query('accounts', where: 'id = ?', whereArgs: [transaction['account_id']]);
    if (account.isEmpty) throw Exception('Account not found');

    final accountData = account.first;
    final accountCurrency = accountData['currency'] as String;
    final transactionCurrency = transaction['currency'] as String;
    double amount = transaction['amount'] as double;

    if (accountCurrency != transactionCurrency) {
      amount = await ExchangeRateService.localConvert(amount, transactionCurrency, accountCurrency);
    }

    final transactionId = await db.insert('transactions', transaction);

    if (transaction['type'] == 'transfer' && transaction['linked_account_id'] != null) {
      final linkedAccount = await db.query('accounts', where: 'id = ?', whereArgs: [transaction['linked_account_id']]);
      if (linkedAccount.isEmpty) throw Exception('Linked account not found');

      final linkedAccountData = linkedAccount.first;
      final linkedAccountCurrency = linkedAccountData['currency'] as String;
      double linkedAmount = transaction['amount'] as double;

      if (linkedAccountCurrency != transactionCurrency) {
        linkedAmount = await ExchangeRateService.localConvert(linkedAmount, transactionCurrency, linkedAccountCurrency);
      }

      // ❌ Restar en origen
      await db.update('accounts', {
        'balance': (accountData['balance'] as double) - amount,
      }, where: 'id = ?', whereArgs: [transaction['account_id']]);

      // ✅ Sumar en destino
      await db.update('accounts', {
        'balance': (linkedAccountData['balance'] as double) + linkedAmount,
      }, where: 'id = ?', whereArgs: [transaction['linked_account_id']]);
    } else {
      double newBalance = (accountData['balance'] as double) + (transaction['type'] == 'expense' ? -amount : amount);
      await db.update('accounts', {'balance': newBalance}, where: 'id = ?', whereArgs: [transaction['account_id']]);
    }

    return transactionId;
  }

  Future<int> updateTransaction(int id, Map<String, dynamic> newTransaction) async {
    final db = await database;

    final oldTransactionList = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (oldTransactionList.isEmpty) throw Exception('Transaction not found');

    final oldTransaction = oldTransactionList.first;

    // Validar cambios
    bool changed = false;
    for (var key in ['account_id', 'linked_account_id', 'amount', 'currency', 'type']) {
      if (oldTransaction[key] != newTransaction[key]) {
        changed = true;
        break;
      }
    }

    if (!changed) {
      // Si no cambió nada relevante, no hacemos nada
      return 0;
    }

    await deleteTransaction(id);
    await addTransaction(newTransaction);

    return 1;
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;

    final transactionList = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (transactionList.isEmpty) throw Exception('Transaction not found');

    final transaction = transactionList.first;
    final account = await db.query('accounts', where: 'id = ?', whereArgs: [transaction['account_id']]);
    if (account.isEmpty) throw Exception('Account not found');

    final accountData = account.first;
    final accountCurrency = accountData['currency'] as String;
    final transactionCurrency = transaction['currency'] as String;
    double amount = transaction['amount'] as double;

    if (accountCurrency != transactionCurrency) {
      amount = await ExchangeRateService.localConvert(amount, transactionCurrency, accountCurrency);
    }

    if (transaction['type'] == 'transfer' && transaction['linked_account_id'] != null) {
      final linkedAccount = await db.query('accounts', where: 'id = ?', whereArgs: [transaction['linked_account_id']]);
      if (linkedAccount.isEmpty) throw Exception('Linked account not found');

      final linkedAccountData = linkedAccount.first;
      final linkedAccountCurrency = linkedAccountData['currency'] as String;

      double linkedAmount = transaction['amount'] as double;
      if (linkedAccountCurrency != transactionCurrency) {
        linkedAmount = await ExchangeRateService.localConvert(linkedAmount, transactionCurrency, linkedAccountCurrency);
      }

      // ✅ Revertir en origen (sumar)
      await db.update('accounts', {
        'balance': (accountData['balance'] as double) + amount,
      }, where: 'id = ?', whereArgs: [transaction['account_id']]);

      // ❌ Revertir en destino (restar)
      await db.update('accounts', {
        'balance': (linkedAccountData['balance'] as double) - linkedAmount,
      }, where: 'id = ?', whereArgs: [transaction['linked_account_id']]);
    } else {
      double newBalance = (accountData['balance'] as double) + (transaction['type'] == 'expense' ? amount : -amount);
      await db.update('accounts', {'balance': newBalance}, where: 'id = ?', whereArgs: [transaction['account_id']]);
    }

    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }




  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    List<Map<String, dynamic>> transactions = await db.query(
      'transactions',
      where: "type IN ('income', 'expense', 'transfer')", // 🔥 Asegurar que filtra bien
      orderBy: 'date DESC',
    );

    // 🔍 Debug: Mostrar lo que se está obteniendo
    print('📌 Transacciones obtenidas para el Dashboard: $transactions');

    return transactions;
  }

  Future<List<String>> getAllCurrencies() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT DISTINCT base_currency FROM exchange_rates
    UNION
    SELECT DISTINCT target_currency FROM exchange_rates
  ''');

    return result.map((row) => row['base_currency'] as String).toList();
  }




  Future<List<String>> getAllCurrenciesCodes() async {
    final db = await database;
    final result = await db.query(
      'exchange_rates',
      columns: ['base_currency'],
      distinct: true,
    );

    List<String> currencies = result.map((row) => row['base_currency'] as String).toSet().toList();

    return currencies;
  }


  Future<int> addCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('categories', category);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories');
  }

  Future<int> updateCategory(int id, Map<String, dynamic> updatedCategory) async {
    final db = await database;
    return await db.update(
      'categories',
      updatedCategory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> addScheduledTransaction(Map<String, dynamic> scheduledTransaction) async {
    final db = await database;
    return await db.insert('scheduled_transactions', scheduledTransaction);
  }

  Future<List<Map<String, dynamic>>> getScheduledTransactions() async {
    final db = await database;
    return await db.query('scheduled_transactions');
  }

  Future<int> updateScheduledTransaction(int id, Map<String, dynamic> updatedTransaction) async {
    final db = await database;
    return await db.update(
      'scheduled_transactions',
      updatedTransaction,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteScheduledTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'scheduled_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos corregidos para configuración (settings)
  Future<int> updateSetting(String column, dynamic value) async {
    final db = await database;

    List<String> validColumns = [
      'main_currency',
      'first_day_of_week',
      'first_day_of_month',
      'default_view',
      'backup_enabled',
      'notifications'
    ];

    if (!validColumns.contains(column)) {
      throw Exception("Clave de configuración no válida: $column");
    }

    return await db.update(
      'settings',
      {column: value},
      where: 'id = ?',
      whereArgs: [1], // Solo hay una fila en settings
    );
  }

  Future<Map<String, dynamic>?> getSetting(String column) async {
    final db = await database;

    List<String> validColumns = [
      'main_currency',
      'first_day_of_week',
      'first_day_of_month',
      'default_view',
      'backup_enabled',
      'notifications'
    ];

    if (!validColumns.contains(column)) {
      throw Exception("Clave de configuración no válida: $column");
    }

    List<Map<String, dynamic>> result = await db.query(
      'settings',
      columns: [column],
      where: 'id = ?',
      whereArgs: [1],
    );

    return result.isNotEmpty ? result.first : null;
  }

  // Settings
  Future<Map<String, dynamic>?> getSettings() async {
    final db = await database;
    final result = await db.query('settings', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateSettings(Map<String, dynamic> newSettings) async {
    final db = await database;
    return await db.update('settings', newSettings, where: 'id = ?', whereArgs: [1]);
  }

  // Exchange Rates

  // ✅ Obtener tasa de cambio de una moneda a otra
  Future<double> getExchangeRate(String baseCurrency, String targetCurrency) async {
    final db = await database;

    // Si las monedas son iguales, no hay conversión
    if (baseCurrency == targetCurrency) {
      return 1.0;
    }

    final result = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [baseCurrency, targetCurrency],
      limit: 1,
    );

    if (result.isEmpty) {
      throw Exception('No se encontró tasa de cambio de $baseCurrency a $targetCurrency');
    }

    return result.first['rate'] as double;
  }

  Future<List<Map<String, dynamic>>> getExchangeRates() async {
    final db = await database;
    return await db.query('exchange_rates');
  }

  Future<List<Map<String, dynamic>>> getCustomExchangeRatesLog() async {
    final db = await database;
    return await db.query('custom_exchange_rates_log', orderBy: 'updated_at DESC');
  }

  Future<int> insertCustomExchangeRate(Map<String, dynamic> rateData) async {
    final db = await database;
    return await db.insert('custom_exchange_rates_log', rateData);
  }

  Future<int> updateExchangeRate(String baseCurrency, String targetCurrency, double newRate) async {
    final db = await database;
    return await db.update(
      'exchange_rates',
      {'rate': newRate, 'last_updated': DateTime.now().toIso8601String()},
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [baseCurrency, targetCurrency],
    );
  }

  /// ✅ Corregido: Obtener una tasa de cambio guardada
  Future<Map<String, dynamic>?> getExchangeRateDetails(String fromCurrency, String toCurrency) async {
    final db = await database;

    final result = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [fromCurrency, toCurrency],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }



  /// Guardar o actualizar una tasa de cambio
  Future<void> saveOrUpdateExchangeRate(String fromCurrency, String toCurrency, double rate) async {
    final db = await database;

    final existing = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [fromCurrency, toCurrency],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'exchange_rates',
        {
          'rate': rate,
          'last_updated': DateTime.now().toIso8601String(),
        },
        where: 'base_currency = ? AND target_currency = ?',
        whereArgs: [fromCurrency, toCurrency],
      );
    } else {
      await db.insert('exchange_rates', {
        'base_currency': fromCurrency,
        'target_currency': toCurrency,
        'rate': rate,
        'last_updated': DateTime.now().toIso8601String(),
      });
    }
  }


  /// Actualizar manualmente una tasa de cambio
  Future<void> updateExchangeRateManual(String fromCurrency, String toCurrency, double newRate) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'exchange_rates',
      {
        'rate': newRate,
        'last_updated': now,
      },
      where: 'from_currency = ? AND to_currency = ?',
      whereArgs: [fromCurrency, toCurrency],
    );
  }

  Future<void> insertCurrencyName(String code, String name) async {
    final db = await database;
    await db.insert('currency_names', {'code': code, 'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<String?> getCurrencyName(String code) async {
    final db = await database;
    final result = await db.query('currency_names', where: 'code = ?', whereArgs: [code], limit: 1);
    return result.isNotEmpty ? result.first['name'] as String : null;
  }




  // Método para cerrar la base de datos
  Future<void> closeDatabase() async {
    final db = await database;
    db.close();
  }
  // Método para eliminar la base de datos manualmente si persisten los errores
  Future<void> resetDatabase() async {
    final path = join(await getDatabasesPath(), 'cashflowx.db');
    await deleteDatabase(path);
    print("Base de datos eliminada.");
  }
}