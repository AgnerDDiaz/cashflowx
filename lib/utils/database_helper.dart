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
      version: 4, // Incrementamos la versión para forzar recreación
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE accounts ADD COLUMN interest_rate REAL DEFAULT 0");
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE transactions ADD COLUMN note TEXT DEFAULT NULL");
        }
      },

    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 🛠️ Creación de Tablas
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
      balance_mode TEXT NOT NULL CHECK (balance_mode IN ('debit', 'credit', 'default')) DEFAULT 'default'

    )
  ''');

    await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
      parent_id INTEGER DEFAULT NULL,
      FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL, -- Cuenta de origen
      linked_account_id INTEGER, -- Cuenta de destino (nullable)
      type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
      amount REAL NOT NULL CHECK (amount > 0), -- Evita montos negativos
      category_id INTEGER DEFAULT NULL,
      date TEXT NOT NULL,
      note TEXT DEFAULT NULL,
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
      FOREIGN KEY (linked_account_id) REFERENCES accounts(id) ON DELETE CASCADE,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
      CHECK (type <> 'transfer' OR linked_account_id IS NOT NULL) -- Verifica que las transferencias tengan cuenta destino
    )
  ''');


    await db.execute('''
    CREATE TABLE settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      main_currency TEXT NOT NULL,
      first_day_of_week TEXT DEFAULT 'Monday',
      first_day_of_month TEXT DEFAULT '1st',
      default_view TEXT DEFAULT 'weekly',
      backup_enabled INTEGER DEFAULT 0,
      notifications INTEGER DEFAULT 1
    )
  ''');

    // 📌 **Insertar Configuración por Defecto**
    await db.insert('settings', {
      'main_currency': 'USD',
      'first_day_of_week': 'Monday',
      'first_day_of_month': '1st',
      'default_view': 'weekly',
      'backup_enabled': 0,
      'notifications': 1
    });

    // 📌 Insertar Categorías y Subcategorías de prueba
    await insertCategoriesAndSubcategories(db);

    // 📌 Insertar Cuentas por Defecto
    List<Map<String, dynamic>> defaultAccounts = [
      {
        'name': 'Cartera',
        'type': 'normal',
        'category': 'Dinero físico',
        'balance': 500.00,
        'currency': 'DOP',
        'balance_mode': 'default'
      },
      {
        'name': 'Banreservas Ahorro',
        'type': 'saving',
        'category': 'Cuentas de ahorros',
        'balance': 10000.00,
        'currency': 'DOP',
        'interest_rate': 4.00,
        'interest_period': 'mensual',
        'penalty_rate': 0.15,
        'balance_mode': 'debit'
      },
      {
        'name': 'Corriente',
        'type': 'current',
        'category': 'Cuentas corrientes',
        'balance': 0.00,
        'currency': 'DOP',
        'penalty_fixed': 1000.00,
        'balance_mode': 'debit'
      },
      {
        'name': 'Tarjeta de Crédito',
        'type': 'credit',
        'category': 'Tarjetas de Crédito',
        'balance': 50000.00,
        'currency': 'DOP',
        'due_date': '23',
        'cutoff_date': '1',
        'balance_mode': 'credit'
      },
      {
        'name': 'Deuda',
        'type': 'debt',
        'category': 'Deudas',
        'balance': 150000.00,
        'currency': 'DOP',
        'due_date': '15',
        'balance_mode': 'credit'
      },
    ];


    for (var account in defaultAccounts) {
      await db.insert('accounts', account);
    }
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

    // Asegurar que `linked_account_id` esté presente en transferencias
    if (transaction['type'] == 'transfer' && !transaction.containsKey('linked_account_id')) {
      print("⚠️ ERROR: No se especificó una cuenta destino para la transferencia.");
      throw Exception("Debes seleccionar una cuenta destino para la transferencia.");
    }

    int id = await db.insert(
      'transactions',
      {
        'account_id': transaction['account_id'],
        'linked_account_id': transaction['type'] == 'transfer' ? transaction['linked_account_id'] : null, // ✅ Solución
        'type': transaction['type'],
        'amount': transaction['amount'],
        'category_id': transaction['category_id'],
        'date': transaction['date'],
        'note': transaction['note'],
      },
    );

    // 🔍 Debug: Verificar si la transacción fue insertada
    final transactions = await db.query('transactions');
    print('📌 Transacciones Registradas en DB: $transactions');

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


  Future<int> updateTransaction(int id, Map<String, dynamic> transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction,
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future<int> deleteTransaction(int id) async {
    final db = await database;
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