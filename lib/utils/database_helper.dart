import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; // kDebugMode

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

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
      version: 12, // v12: recurrencias robustas (is_active, error log, tz, índices) + scheduled_id en transactions
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // -------------------------
  // onCreate: esquema final
  // -------------------------
  Future<void> _onCreate(Database db, int version) async {
    // account_groups
    await db.execute('''
      CREATE TABLE account_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER DEFAULT 0,
        color TEXT DEFAULT NULL,
        collapsed INTEGER DEFAULT 0
      );
    ''');

    // Crear grupo por defecto "General"
    await db.insert(
      'account_groups',
      {'name': 'General', 'sort_order': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // accounts (SIN category/intereses/penalidades)
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        currency TEXT NOT NULL,
        balance_mode TEXT NOT NULL CHECK (balance_mode IN ('debit','credit','default')) DEFAULT 'default',
        due_date TEXT DEFAULT NULL,
        cutoff_date TEXT DEFAULT NULL,
        max_credit REAL DEFAULT NULL,
        visible INTEGER DEFAULT 1,
        include_in_balance INTEGER DEFAULT 1,
        group_id INTEGER,
        FOREIGN KEY (group_id) REFERENCES account_groups(id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_group ON accounts(group_id);');

    // Triggers para garantizar group_id (si viene NULL → "General")
    await db.execute('''
    CREATE TRIGGER IF NOT EXISTS trg_accounts_default_group_after_insert
    AFTER INSERT ON accounts
    FOR EACH ROW
    WHEN NEW.group_id IS NULL
    BEGIN
      UPDATE accounts
      SET group_id = (SELECT id FROM account_groups WHERE name='General' LIMIT 1)
      WHERE id = NEW.id;
    END;
    ''');

    await db.execute('''
    CREATE TRIGGER IF NOT EXISTS trg_accounts_default_group_after_update
    AFTER UPDATE ON accounts
    FOR EACH ROW
    WHEN NEW.group_id IS NULL
    BEGIN
      UPDATE accounts
      SET group_id = (SELECT id FROM account_groups WHERE name='General' LIMIT 1)
      WHERE id = NEW.id;
    END;
    ''');

    // exchange_rates
    await db.execute('''
      CREATE TABLE exchange_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        base_currency TEXT NOT NULL,
        target_currency TEXT NOT NULL,
        rate REAL NOT NULL,
        last_updated TEXT NOT NULL
      );
    ''');

    // categories (con jerarquía)
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income','expense')),
        parent_id INTEGER DEFAULT NULL,
        FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE
      );
    ''');
    await db.execute("CREATE INDEX IF NOT EXISTS idx_cat_parent ON categories(parent_id);");

    // -------------------------------
    // scheduled_transactions (final)
    // -------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scheduled_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        linked_account_id INTEGER,
        type TEXT NOT NULL CHECK (type IN ('income','expense','transfer')),
        amount REAL NOT NULL CHECK (amount > 0),
        currency TEXT NOT NULL DEFAULT 'DOP',
        category_id INTEGER,
        start_date TEXT NOT NULL,
        end_date TEXT NULL,
        frequency TEXT NOT NULL,
        next_run TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        failed_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NULL,
        tz TEXT NOT NULL DEFAULT 'UTC',
        note TEXT,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (linked_account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_sched_active_next_run ON scheduled_transactions(is_active, next_run);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sched_next_run ON scheduled_transactions(next_run);');

    // transactions (ahora con scheduled_id)
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        linked_account_id INTEGER,
        type TEXT NOT NULL CHECK (type IN ('income','expense','transfer')),
        amount REAL NOT NULL CHECK (amount > 0),
        currency TEXT NOT NULL DEFAULT 'DOP',
        category_id INTEGER DEFAULT NULL,
        date TEXT NOT NULL,
        note TEXT DEFAULT NULL,
        scheduled_id INTEGER NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (linked_account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
        FOREIGN KEY (scheduled_id) REFERENCES scheduled_transactions(id) ON DELETE SET NULL,
        CHECK (type <> 'transfer' OR linked_account_id IS NOT NULL)
      );
    ''');
    await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_date ON transactions(date);");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_account ON transactions(account_id);");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_linked ON transactions(linked_account_id);");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_scheduled ON transactions(scheduled_id);");
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_tx_sched_date
      ON transactions(scheduled_id, date)
      WHERE scheduled_id IS NOT NULL;
    ''');

    // budgets
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER NOT NULL,
        monto_maximo REAL NOT NULL,
        periodo TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        FOREIGN KEY (categoria_id) REFERENCES categories(id) ON DELETE CASCADE
      );
    ''');

    // settings + fila por defecto
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
      );
    ''');
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
      'rate_update_interval_days': 30,
    });

    // custom_exchange_rates_log
    await db.execute('''
      CREATE TABLE custom_exchange_rates_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        base_currency TEXT NOT NULL,
        target_currency TEXT NOT NULL,
        rate REAL NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // currency_names
    await db.execute('''
      CREATE TABLE currency_names (
        code TEXT PRIMARY KEY,
        name TEXT
      );
    ''');

    // seeds base de monedas
    await db.insert('currency_names', {'code': 'USD', 'name': 'United States Dollar'});
    await db.insert('currency_names', {'code': 'DOP', 'name': 'Dominican Peso'});
    await db.insert('currency_names', {'code': 'EUR', 'name': 'Euro'});
    await db.insert('currency_names', {'code': 'JPY', 'name': 'Japanese Yen'});

    // categorías por defecto
    await insertCategoriesAndSubcategories(db);

    // seeds SOLO en desarrollo
    if (kDebugMode) {
      await insertDevGroupsAndAccounts(db); // usa group_id
      await insertTestTransactions(db);
      await insertSampleExchangeRates(db);
    }
  }

  // -------------------------
  // onUpgrade: migraciones
  // -------------------------
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v6
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE settings ADD COLUMN secondary_currency TEXT DEFAULT 'USD';");
      await db.execute("ALTER TABLE settings ADD COLUMN theme_mode TEXT DEFAULT 'system';");
      await db.execute("ALTER TABLE settings ADD COLUMN language TEXT DEFAULT 'es';");
      await db.execute("ALTER TABLE settings ADD COLUMN biometric_enabled INTEGER DEFAULT 0;");
      await db.execute("ALTER TABLE settings ADD COLUMN pin_code TEXT DEFAULT NULL;");
      await db.execute("ALTER TABLE settings ADD COLUMN auto_update_rates INTEGER DEFAULT 1;");
      await db.execute("ALTER TABLE settings ADD COLUMN rate_update_interval_days INTEGER DEFAULT 30;");

      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_exchange_rates_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          base_currency TEXT NOT NULL,
          target_currency TEXT NOT NULL,
          rate REAL NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS currency_names (
          code TEXT PRIMARY KEY,
          name TEXT
        );
      ''');
    }

    // v7
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS scheduled_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          linked_account_id INTEGER,
          type TEXT NOT NULL CHECK (type IN ('income','expense','transfer')),
          amount REAL NOT NULL CHECK (amount > 0),
          currency TEXT NOT NULL DEFAULT 'DOP',
          category_id INTEGER,
          start_date TEXT NOT NULL,
          frequency TEXT NOT NULL,
          next_run TEXT NOT NULL,
          note TEXT,
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
          FOREIGN KEY (linked_account_id) REFERENCES accounts(id) ON DELETE CASCADE,
          FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
        );
      ''');

      await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_date ON transactions(date);");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_account ON transactions(account_id);");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_linked ON transactions(linked_account_id);");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_cat_parent ON categories(parent_id);");

      try {
        await db.execute('''
          UPDATE settings
          SET first_day_of_week = 
            CASE LOWER(first_day_of_week)
              WHEN 'sunday' THEN 'sunday'
              WHEN 'monday' THEN 'monday'
              WHEN 'lunes' THEN 'monday'
              WHEN 'domingo' THEN 'sunday'
              ELSE 'monday'
            END
          WHERE id = 1;
        ''');
      } catch (_) {}
    }

    // v8
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          sort_order INTEGER DEFAULT 0,
          color TEXT DEFAULT NULL,
          collapsed INTEGER DEFAULT 0
        );
      ''');

      try { await db.execute("ALTER TABLE accounts ADD COLUMN group_id INTEGER;"); } catch (_) {}

      final cats = await db.rawQuery('SELECT DISTINCT category FROM accounts WHERE category IS NOT NULL AND TRIM(category) <> ""');
      for (final row in cats) {
        final name = (row['category'] as String).trim();
        if (name.isEmpty) continue;
        await db.insert('account_groups', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final groups = await db.query('account_groups', columns: ['id','name']);
      final idByName = { for (final g in groups) (g['name'] as String): (g['id'] as int) };
      final accs = await db.query('accounts', columns: ['id','category']);
      for (final a in accs) {
        final name = (a['category'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final gid = idByName[name];
        if (gid != null) {
          await db.update('accounts', {'group_id': gid}, where: 'id = ?', whereArgs: [a['id']]);
        }
      }

      await db.execute("CREATE INDEX IF NOT EXISTS idx_accounts_group ON accounts(group_id);");
    }

    // v9: reconstruir accounts SIN 'category' ni intereses/penalidades
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE accounts_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          balance REAL NOT NULL,
          currency TEXT NOT NULL,
          balance_mode TEXT NOT NULL CHECK (balance_mode IN ('debit','credit','default')) DEFAULT 'default',
          due_date TEXT DEFAULT NULL,
          cutoff_date TEXT DEFAULT NULL,
          max_credit REAL DEFAULT NULL,
          visible INTEGER DEFAULT 1,
          include_in_balance INTEGER DEFAULT 1,
          group_id INTEGER,
          FOREIGN KEY (group_id) REFERENCES account_groups(id) ON DELETE SET NULL
        );
      ''');

      final accs = await db.query('accounts');
      for (final a in accs) {
        await db.insert('accounts_new', {
          'id': a['id'],
          'name': a['name'],
          'type': a['type'],
          'balance': a['balance'],
          'currency': a['currency'],
          'balance_mode': a['balance_mode'],
          'due_date': a['due_date'],
          'cutoff_date': a['cutoff_date'],
          'max_credit': a['max_credit'],
          'visible': a['visible'],
          'include_in_balance': a['include_in_balance'],
          'group_id': a['group_id'],
        });
      }

      await db.execute('DROP TABLE accounts;');
      await db.execute('ALTER TABLE accounts_new RENAME TO accounts;');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_group ON accounts(group_id);');
    }

    // v10: default group + backfill + triggers
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          sort_order INTEGER DEFAULT 0,
          color TEXT DEFAULT NULL,
          collapsed INTEGER DEFAULT 0
        );
      ''');

      await db.insert(
        'account_groups',
        {'name': 'General', 'sort_order': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await db.execute('''
        UPDATE accounts
        SET group_id = (SELECT id FROM account_groups WHERE name='General' LIMIT 1)
        WHERE group_id IS NULL;
      ''');

      await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_accounts_default_group_after_insert
      AFTER INSERT ON accounts
      FOR EACH ROW
      WHEN NEW.group_id IS NULL
      BEGIN
        UPDATE accounts
        SET group_id = (SELECT id FROM account_groups WHERE name='General' LIMIT 1)
        WHERE id = NEW.id;
      END;
      ''');

      await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_accounts_default_group_after_update
      AFTER UPDATE ON accounts
      FOR EACH ROW
      WHEN NEW.group_id IS NULL
      BEGIN
        UPDATE accounts
        SET group_id = (SELECT id FROM account_groups WHERE name='General' LIMIT 1)
        WHERE id = NEW.id;
      END;
      ''');
    }

    // v11: end_date en scheduled
    if (oldVersion < 11) {
      try { await db.execute("ALTER TABLE scheduled_transactions ADD COLUMN end_date TEXT NULL;"); } catch (_) {}
    }

    // v12: robustecer recurrencias + scheduled_id en transactions + índices
    if (oldVersion < 12) {
      try { await db.execute("ALTER TABLE scheduled_transactions ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;"); } catch (_) {}
      try { await db.execute("ALTER TABLE scheduled_transactions ADD COLUMN failed_count INTEGER NOT NULL DEFAULT 0;"); } catch (_) {}
      try { await db.execute("ALTER TABLE scheduled_transactions ADD COLUMN last_error TEXT NULL;"); } catch (_) {}
      try { await db.execute("ALTER TABLE scheduled_transactions ADD COLUMN tz TEXT NOT NULL DEFAULT 'UTC';"); } catch (_) {}

      await db.execute('CREATE INDEX IF NOT EXISTS idx_sched_active_next_run ON scheduled_transactions(is_active, next_run);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sched_next_run ON scheduled_transactions(next_run);');

      try { await db.execute("ALTER TABLE transactions ADD COLUMN scheduled_id INTEGER NULL;"); } catch (_) {}
      await db.execute("CREATE INDEX IF NOT EXISTS idx_txn_scheduled ON transactions(scheduled_id);");
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS uq_tx_sched_date
        ON transactions(scheduled_id, date)
        WHERE scheduled_id IS NOT NULL;
      ''');
    }
  }

  // -------------------------
  // Helpers / Seeds (solo dev)
  // -------------------------
  Future<void> insertSampleExchangeRates(Database db) async {
    final rows = [
      {'base_currency': 'USD', 'target_currency': 'DOP', 'rate': 58.5,  'last_updated': '2025-04-03'},
      {'base_currency': 'EUR', 'target_currency': 'DOP', 'rate': 63.75, 'last_updated': '2025-04-03'},
      {'base_currency': 'GBP', 'target_currency': 'DOP', 'rate': 74.23, 'last_updated': '2025-04-03'},
      {'base_currency': 'CAD', 'target_currency': 'DOP', 'rate': 42.15, 'last_updated': '2025-04-03'},
      {'base_currency': 'JPY', 'target_currency': 'DOP', 'rate': 0.53,  'last_updated': '2025-04-03'},
      {'base_currency': 'MXN', 'target_currency': 'DOP', 'rate': 3.42,  'last_updated': '2025-04-03'},
      {'base_currency': 'CHF', 'target_currency': 'DOP', 'rate': 64.11, 'last_updated': '2025-04-03'},
    ];
    for (final r in rows) { await db.insert('exchange_rates', r); }
  }

  Future<void> insertDevGroupsAndAccounts(Database db) async {
    final names = ['Cuentas personales','Cuentas del negocio','Ahorros','Tarjetas de crédito','Deudas'];
    final gid = <String,int>{};
    for (final n in names) {
      await db.insert('account_groups', {'name': n}, conflictAlgorithm: ConflictAlgorithm.ignore);
      final row = (await db.query('account_groups', where: 'name = ?', whereArgs: [n], limit: 1)).first;
      gid[n] = row['id'] as int;
    }

    final accounts = [
      {
        'name': 'Cuenta Banreservas',
        'type': 'normal',
        'group_id': gid['Cuentas personales'],
        'balance': 46.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 0,
        'visible': 0,
      },
      {
        'name': 'Cuenta Popular (carrito)',
        'type': 'normal',
        'group_id': gid['Cuentas personales'],
        'balance': 2260.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Cuenta BHD (SamTech)',
        'type': 'normal',
        'group_id': gid['Cuentas del negocio'],
        'balance': 13067.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Tarjeta gold Banreservas',
        'type': 'credit',
        'group_id': gid['Tarjetas de crédito'],
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
        'group_id': gid['Tarjetas de crédito'],
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
        'group_id': gid['Tarjetas de crédito'],
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
        'group_id': gid['Deudas'],
        'balance': -5758.76,
        'currency': 'USD',
        'balance_mode': 'credit',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Fondo de emergencia',
        'type': 'saving',
        'group_id': gid['Ahorros'],
        'balance': 5044.00,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
    ];
    for (final a in accounts) { await db.insert('accounts', a); }
  }

  Future<void> insertCategoriesAndSubcategories(Database db) async {
    final defaultCategories = [
      {'name': 'Transporte', 'type': 'expense', 'parent_id': null},
      {'name': 'Comida', 'type': 'expense', 'parent_id': null},
      {'name': 'Hogar', 'type': 'expense', 'parent_id': null},
      {'name': 'Deudas', 'type': 'expense', 'parent_id': null},
      {'name': 'Salud', 'type': 'expense', 'parent_id': null},
      {'name': 'Sueldo', 'type': 'income', 'parent_id': null},
      {'name': 'Bono', 'type': 'income', 'parent_id': null},
    ];
    for (final c in defaultCategories) {
      await db.insert('categories', c, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    Future<int?> idOf(String name) async {
      final r = await db.query('categories', columns: ['id'], where: 'name = ?', whereArgs: [name], limit: 1);
      return r.isNotEmpty ? r.first['id'] as int : null;
    }

    final sub = [
      {'name': 'Gasolina', 'type': 'expense', 'parent_id': await idOf('Transporte')},
      {'name': 'Taxi/Uber', 'type': 'expense', 'parent_id': await idOf('Transporte')},
      {'name': 'Pasajes', 'type': 'expense', 'parent_id': await idOf('Transporte')},

      {'name': 'Comida Rápida', 'type': 'expense', 'parent_id': await idOf('Comida')},
      {'name': 'Restaurante', 'type': 'expense', 'parent_id': await idOf('Comida')},
      {'name': 'Supermercado', 'type': 'expense', 'parent_id': await idOf('Comida')},

      {'name': 'Alquiler', 'type': 'expense', 'parent_id': await idOf('Hogar')},
      {'name': 'Servicios (Luz, Agua, Internet)', 'type': 'expense', 'parent_id': await idOf('Hogar')},
      {'name': 'Mantenimiento', 'type': 'expense', 'parent_id': await idOf('Hogar')},

      {'name': 'Médico', 'type': 'expense', 'parent_id': await idOf('Salud')},
      {'name': 'Medicinas', 'type': 'expense', 'parent_id': await idOf('Salud')},
      {'name': 'Gimnasio', 'type': 'expense', 'parent_id': await idOf('Salud')},

      {'name': 'Sueldo Base', 'type': 'income', 'parent_id': await idOf('Sueldo')},
      {'name': 'Horas Extras', 'type': 'income', 'parent_id': await idOf('Sueldo')},

      {'name': 'Bono Anual', 'type': 'income', 'parent_id': await idOf('Bono')},
      {'name': 'Bono de Producción', 'type': 'income', 'parent_id': await idOf('Bono')},
    ];
    for (final s in sub) {
      await db.insert('categories', s, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> insertTestTransactions(Database db) async {
    Future<int?> idOfCategory(String name) async {
      final r = await db.query('categories', columns: ['id'], where: 'name = ?', whereArgs: [name], limit: 1);
      return r.isNotEmpty ? r.first['id'] as int : null;
    }

    final rows = [
      {
        'account_id': 1,
        'type': 'expense',
        'amount': 200.0,
        'currency': 'DOP',
        'category_id': await idOfCategory('Comida'),
        'date': '2025-03-18',
        'note': 'Cena en restaurante'
      },
      {
        'account_id': 1,
        'type': 'expense',
        'amount': 100.0,
        'currency': 'DOP',
        'category_id': await idOfCategory('Transporte'),
        'date': '2025-03-18',
        'note': 'Taxi'
      },
      {
        'account_id': 2,
        'type': 'income',
        'amount': 10000.0,
        'currency': 'DOP',
        'category_id': await idOfCategory('Sueldo'),
        'date': '2025-03-17',
        'note': 'Salario mensual'
      },
      {
        'account_id': 3,
        'type': 'transfer',
        'amount': 2000.0,
        'currency': 'DOP',
        'category_id': null,
        'linked_account_id': 4,
        'date': '2025-03-16',
        'note': 'Pago de tarjeta de crédito'
      },
      {
        'account_id': 4,
        'type': 'expense',
        'amount': 5000.0,
        'currency': 'DOP',
        'category_id': await idOfCategory('Deudas'),
        'date': '2025-03-15',
        'note': 'Pago parcial de deuda'
      },
    ];
    for (final t in rows) { await db.insert('transactions', t); }
  }

  // utilidades
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  Future<void> resetDatabase() async {
    final path = join(await getDatabasesPath(), 'cashflowx.db');
    await deleteDatabase(path);
    debugPrint("Base de datos eliminada (manual).");
  }
}
