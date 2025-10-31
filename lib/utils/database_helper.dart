// lib/utils/database_helper.dart
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
      version: 15, // v14: agrega/rellena cutoff_date & due_date para TC + meta; mantiene v13 intacta
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

    // Grupo por defecto "General"
    await db.insert(
      'account_groups',
      {'name': 'General', 'sort_order': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // accounts
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        currency TEXT NOT NULL,
        balance_mode TEXT NOT NULL CHECK (balance_mode IN ('debit','credit','default')) DEFAULT 'default',
        due_date TEXT DEFAULT NULL,       -- día de pago (1..28) o 'YYYY-MM-DD'
        cutoff_date TEXT DEFAULT NULL,    -- día de corte (1..28) o 'YYYY-MM-DD'
        max_credit REAL DEFAULT NULL,
        visible INTEGER DEFAULT 1,
        include_in_balance INTEGER DEFAULT 1,
        group_id INTEGER,
        sort_order INTEGER DEFAULT 0
        FOREIGN KEY (group_id) REFERENCES account_groups(id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_group ON accounts(group_id);');

    // Triggers: si group_id viene NULL => "General"
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

    // scheduled_transactions
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

    // transactions
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

    // currency_names (catálogo mínimo)
    await db.execute('''
      CREATE TABLE currency_names (
        code TEXT PRIMARY KEY,
        name TEXT
      );
    ''');
    await db.insert('currency_names', {'code': 'USD', 'name': 'United States Dollar'});
    await db.insert('currency_names', {'code': 'EUR', 'name': 'Euro'});
    await db.insert('currency_names', {'code': 'DOP', 'name': 'Dominican Peso'});

    // credit_cards_meta
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_cards_meta (
        account_id INTEGER PRIMARY KEY,
        statement_day INTEGER NULL,
        due_day INTEGER NULL,
        statement_due REAL NOT NULL DEFAULT 0,
        post_statement REAL NOT NULL DEFAULT 0,
        credit_limit REAL NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
      );
    ''');

    // Categorías por defecto
    await insertCategoriesAndSubcategories(db);

    // Tipos de cambio mínimos
    await _seedBasicExchangeRates(db);

    // ---- Seeds SOLO DEV: grupos + CUENTAS en 0.0 (incluye tus 3 tarjetas) ----
    if (kDebugMode) {
      await insertDevGroupsAndZeroAccounts(db);
    }
  }

  // -------------------------
  // onUpgrade: migraciones
  // -------------------------
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

      // Este bloque suponía una columna 'category' legacy.
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

    if (oldVersion < 11) {
      try { await db.execute("ALTER TABLE scheduled_transactions ADD COLUMN end_date TEXT NULL;"); } catch (_) {}
    }

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

    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credit_cards_meta (
          account_id INTEGER PRIMARY KEY,
          statement_day INTEGER NULL,
          due_day INTEGER NULL,
          statement_due REAL NOT NULL DEFAULT 0,
          post_statement REAL NOT NULL DEFAULT 0,
          credit_limit REAL NULL,
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
      ''');

      await db.insert('currency_names', {'code': 'USD', 'name': 'United States Dollar'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('currency_names', {'code': 'EUR', 'name': 'Euro'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('currency_names', {'code': 'DOP', 'name': 'Dominican Peso'}, conflictAlgorithm: ConflictAlgorithm.ignore);

      await _seedBasicExchangeRates(db);
    }

    if (oldVersion < 14) {
      await db.execute("""
        UPDATE accounts
        SET cutoff_date = '10'
        WHERE type = 'credit' AND (cutoff_date IS NULL OR TRIM(cutoff_date) = '');
      """);

      await db.execute("""
        UPDATE accounts
        SET due_date = '24'
        WHERE type = 'credit' AND (due_date IS NULL OR TRIM(due_date) = '');
      """);

      await db.execute("""
        CREATE TABLE IF NOT EXISTS credit_cards_meta (
          account_id INTEGER PRIMARY KEY,
          statement_day INTEGER NULL,
          due_day INTEGER NULL,
          statement_due REAL NOT NULL DEFAULT 0,
          post_statement REAL NOT NULL DEFAULT 0,
          credit_limit REAL NULL,
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
      """);

      await db.execute("""
        INSERT OR IGNORE INTO credit_cards_meta (account_id, statement_day, due_day, statement_due, post_statement, credit_limit)
        SELECT id, NULL, NULL, 0.0, 0.0, max_credit
        FROM accounts WHERE type = 'credit';
      """);

      await db.execute("""
        UPDATE credit_cards_meta
        SET statement_day = COALESCE(
              statement_day,
              CAST((SELECT cutoff_date FROM accounts WHERE accounts.id = credit_cards_meta.account_id) AS INTEGER)
            ),
            due_day = COALESCE(
              due_day,
              CAST((SELECT due_date FROM accounts WHERE accounts.id = credit_cards_meta.account_id) AS INTEGER)
            ),
            credit_limit = COALESCE(
              credit_limit,
              (SELECT max_credit FROM accounts WHERE accounts.id = credit_cards_meta.account_id)
            )
        WHERE account_id IN (SELECT id FROM accounts WHERE type = 'credit');
      """);
    }

    if (oldVersion < 15) {
      try { await db.execute("ALTER TABLE accounts ADD COLUMN sort_order INTEGER DEFAULT 0;"); } catch (_) {}
      await db.execute("CREATE INDEX IF NOT EXISTS idx_accounts_group_sort ON accounts(group_id, sort_order);");

      // Inicializa sort_order por grupo según id ascendente
      final rows = await db.rawQuery('SELECT id, group_id FROM accounts ORDER BY group_id, id');
      int? currentGroup;
      int order = 0;
      for (final r in rows) {
        final gid = r['group_id'] as int?;
        if (gid != currentGroup) { currentGroup = gid; order = 0; }
        await db.update('accounts', {'sort_order': order++}, where: 'id = ?', whereArgs: [r['id']]);
      }
    }

  }

  // -------------------------
  // Seeds / Helpers
  // -------------------------

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
      final r = await db.query(
        'categories',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
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

  /// Inserta tipos de cambio mínimos (USD↔EUR y USD↔DOP), reemplazando si existen.
  Future<void> _seedBasicExchangeRates(Database db) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    Future<void> put(String base, String target, double rate) async {
      await db.insert(
        'exchange_rates',
        {
          'base_currency': base,
          'target_currency': target,
          'rate': rate,
          'last_updated': today,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    const usdToEur = 0.92;
    await put('USD', 'EUR', usdToEur);
    await put('EUR', 'USD', 1 / usdToEur);

    const usdToDop = 59.5;
    await put('USD', 'DOP', usdToDop);
    await put('DOP', 'USD', 1 / usdToDop);
  }

  /// Seeds DEV: grupos + cuentas en 0.0 (incluye 3 tarjetas con días distintos)
  Future<void> insertDevGroupsAndZeroAccounts(Database db) async {
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
        'balance': 0.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Cuenta Popular (carrito)',
        'type': 'normal',
        'group_id': gid['Cuentas personales'],
        'balance': 0.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Cuenta BHD (SamTech)',
        'type': 'normal',
        'group_id': gid['Cuentas del negocio'],
        'balance': 0.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },

      // ====== TARJETAS DE CRÉDITO ======
      {
        'name': 'Tarjeta gold Banreservas',
        'type': 'credit',
        'group_id': gid['Tarjetas de crédito'],
        'balance': 0.0,
        'currency': 'DOP',
        'balance_mode': 'credit',
        'max_credit': 50000.0,
        'include_in_balance': 1,
        'visible': 1,
        'cutoff_date': '2',   // Corte
        'due_date': '23',     // Pago
      },
      {
        'name': 'Tarjeta de Crédito en Dólares',
        'type': 'credit',
        'group_id': gid['Tarjetas de crédito'],
        'balance': 0.0,
        'currency': 'USD',
        'balance_mode': 'credit',
        'max_credit': 1000.0,
        'include_in_balance': 1,
        'visible': 1,
        'cutoff_date': '10',  // Corte
        'due_date': '28',     // Pago
      },
      {
        'name': 'Tarjeta de crédito personal',
        'type': 'credit',
        'group_id': gid['Tarjetas de crédito'],
        'balance': 0.0,
        'currency': 'DOP',
        'balance_mode': 'credit',
        'max_credit': 50000.0,
        'include_in_balance': 1,
        'visible': 1,
        'cutoff_date': '7',   // Corte
        'due_date': '1',      // Pago
      },
      // ====== FIN TARJETAS ======

      {
        'name': 'Deuda a Eleanny',
        'type': 'debt',
        'group_id': gid['Deudas'],
        'balance': 0.0,
        'currency': 'USD',
        'balance_mode': 'credit',
        'include_in_balance': 1,
        'visible': 1,
      },
      {
        'name': 'Fondo de emergencia',
        'type': 'saving',
        'group_id': gid['Ahorros'],
        'balance': 0.0,
        'currency': 'DOP',
        'balance_mode': 'default',
        'include_in_balance': 1,
        'visible': 1,
      },
    ];

    for (final a in accounts) {
      final accId = await db.insert('accounts', a);
      if (a['type'] == 'credit') {
        final cut = a['cutoff_date']?.toString();
        final due = a['due_date']?.toString();
        final statementDay = cut == null ? null : int.tryParse(cut);
        final dueDay = due == null ? null : int.tryParse(due);

        await db.insert(
          'credit_cards_meta',
          {
            'account_id': accId,
            'statement_day': statementDay,   // día de corte
            'due_day': dueDay,               // día de pago
            'statement_due': 0.0,            // este ciclo
            'post_statement': 0.0,           // próximo ciclo
            'credit_limit': a['max_credit'], // límite
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  // utilidades
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  /// Elimina el archivo de base de datos. Úsalo una sola vez para empezar limpio (DEV).
  Future<void> resetDatabase() async {
    final path = join(await getDatabasesPath(), 'cashflowx.db');
    await deleteDatabase(path);
    debugPrint("Base de datos eliminada (manual).");
    _database = null;
  }
}
