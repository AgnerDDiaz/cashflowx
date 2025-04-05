import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

    await insertCategoriesAndSubcategories(db);
    await insertDefaultAccounts(db);
    await insertTestTransactions(db);

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
        'balance': 5758.76,
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
        'balance_mode': 'default',
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
        'category_id': await getCategoryId('Comida'),
        'date': '2025-03-18',
        'note': 'Cena en restaurante'
      },
      {
        'account_id': 1,
        'type': 'expense',
        'amount': 100.0,
        'category_id': await getCategoryId('Transporte'),
        'date': '2025-03-18',
        'note': 'Taxi'
      },
      {
        'account_id': 2,
        'type': 'income',
        'amount': 10000.0,
        'category_id': await getCategoryId('Sueldo'),
        'date': '2025-03-17',
        'note': 'Salario mensual'
      },
      {
        'account_id': 3,
        'type': 'transfer',
        'amount': 2000.0,
        'category_id': null,
        'linked_account_id': 4, // Asegurar que tiene una cuenta destino
        'date': '2025-03-16',
        'note': 'Pago de tarjeta de crédito'
      },
      {
        'account_id': 4,
        'type': 'expense',
        'amount': 5000.0,
        'category_id': await getCategoryId('Deudas'),
        'date': '2025-03-15',
        'note': 'Pago parcial de deuda'
      },
    ];

    for (var transaction in testTransactions) {
        await db.insert('transactions', transaction);
    }
  }

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
    print("📝 Intentando registrar transacción: $transaction");

    if (transaction['type'] == 'transfer' && !transaction.containsKey('linked_account_id')) {
      throw Exception("Debes seleccionar una cuenta destino para la transferencia.");
    }

    int id = await db.insert('transactions', {
      'account_id': transaction['account_id'],
      'linked_account_id': transaction['type'] == 'transfer' ? transaction['linked_account_id'] : null,
      'type': transaction['type'],
      'amount': transaction['amount'],
      'category_id': transaction['category_id'],
      'date': transaction['date'],
      'note': transaction['note'],
    });

    // ⚡ Actualizar el balance de la(s) cuenta(s)
    if (transaction['type'] == 'income') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [transaction['amount'], transaction['account_id']],
      );
    } else if (transaction['type'] == 'expense') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [transaction['amount'], transaction['account_id']],
      );
    } else if (transaction['type'] == 'transfer') {
      // Gastar en cuenta origen
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [transaction['amount'], transaction['account_id']],
      );
      // Recibir en cuenta destino
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [transaction['amount'], transaction['linked_account_id']],
      );
    }

    return id;
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


  Future<int> updateTransaction(int id, Map<String, dynamic> updatedTransaction) async {
    final db = await database;

    // Obtener la transacción original
    final List<Map<String, dynamic>> oldTransactionList = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (oldTransactionList.isEmpty) {
      throw Exception("No se encontró la transacción para actualizar.");
    }

    final oldTransaction = oldTransactionList.first;

    // Revertir efectos del monto anterior
    if (oldTransaction['type'] == 'income') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['account_id']],
      );
    } else if (oldTransaction['type'] == 'expense') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['account_id']],
      );
    } else if (oldTransaction['type'] == 'transfer') {
      // Revertir movimiento anterior
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['account_id']],
      );
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['linked_account_id']],
      );
    }

    // Actualizar la transacción con los nuevos valores
    int result = await db.update(
      'transactions',
      updatedTransaction,
      where: 'id = ?',
      whereArgs: [id],
    );

    // Aplicar los nuevos efectos
    if (updatedTransaction['type'] == 'income') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [updatedTransaction['amount'], updatedTransaction['account_id']],
      );
    } else if (updatedTransaction['type'] == 'expense') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [updatedTransaction['amount'], updatedTransaction['account_id']],
      );
    } else if (updatedTransaction['type'] == 'transfer') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [updatedTransaction['amount'], updatedTransaction['account_id']],
      );
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [updatedTransaction['amount'], updatedTransaction['linked_account_id']],
      );
    }

    return result;
  }



  Future<int> deleteTransaction(int id) async {
    final db = await database;

    // Obtener la transacción original antes de eliminarla
    final List<Map<String, dynamic>> oldTransactionList = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (oldTransactionList.isEmpty) {
      throw Exception("No se encontró la transacción para eliminar.");
    }

    final oldTransaction = oldTransactionList.first;

    // Revertir efectos del monto antes de eliminar
    if (oldTransaction['type'] == 'income') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['account_id']],
      );
    } else if (oldTransaction['type'] == 'expense') {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['account_id']],
      );
    } else if (oldTransaction['type'] == 'transfer') {
      // Revertir movimiento de transferencia
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['account_id']],
      );
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [oldTransaction['amount'], oldTransaction['linked_account_id']],
      );
    }

    // Eliminar la transacción
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
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