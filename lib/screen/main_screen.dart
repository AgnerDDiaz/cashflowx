import 'package:flutter/material.dart';

// 🔁 Repos
import '../repositories/accounts_repository.dart';
import '../repositories/categories_repository.dart';
import '../repositories/transactions_repository.dart';

// Modelos (para mantener List<Map<String,dynamic>> en memoria)
import '../models/account.dart';
import '../models/category.dart' as model;
import '../models/transaction.dart';

// Screens
import 'dashboard_screen.dart' show DashboardScreen, DashboardScreenState;
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'add_transaction_screen.dart';

// Importa SOLO los símbolos necesarios para evitar choques
import 'accounts_screen.dart' show AccountsScreen, AccountsScreenState;

// Servicios que corren al iniciar
import '../services/scheduled_transactions_processor.dart';

class MainScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;

  const MainScreen({
    Key? key,
    required this.accounts,
    required this.categories,
    required this.transactions,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  late List<Map<String, dynamic>> _accounts;
  late List<Map<String, dynamic>> _categories;
  late List<Map<String, dynamic>> _transactions;

  final _accountsRepo = AccountsRepository();
  final _categoriesRepo = CategoriesRepository();
  final _txRepo = TransactionsRepository();
  final _scheduledProcessor = ScheduledTransactionsProcessor();

  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<AccountsScreenState> _accountsKey = GlobalKey<AccountsScreenState>();

  @override
  void initState() {
    super.initState();


    _accounts = List<Map<String, dynamic>>.from(widget.accounts);
    _categories = List<Map<String, dynamic>>.from(widget.categories);
    _transactions = List<Map<String, dynamic>>.from(widget.transactions);

    // Observador de ciclo de vida
    WidgetsBinding.instance.addObserver(this);

    // Procesar transacciones programadas y cargar data al arrancar (no bloqueante del build)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _scheduledProcessor.runDue();
      await fetchData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Cuando la app vuelve al foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _scheduledProcessor.runDue();
      await fetchData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = ModalRoute.of(context)?.settings;
    if (settings is RouteSettings && settings.arguments is Map) {
      final args = settings.arguments as Map;
      if (args.containsKey('filter') && args.containsKey('date')) {
        DashboardScreen.lastSelectedFilter = args['filter'];
        DashboardScreen.lastSelectedDate = args['date'];
        _currentIndex = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          fetchData();
        });
      }
    }
  }

  Future<void> _onTabTapped(int index) async {
    if (index == 2) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
            accounts: _accounts,
            categories: _categories,
          ),
        ),
      );

      if (result == true) {
        await fetchData();
        _dashboardKey.currentState?.reloadDashboard();
        _accountsKey.currentState?.reloadAccounts(); // ← necesita estar expuesto en AccountsScreenState
        setState(() => _currentIndex = 0);
      }
    } else {
      setState(() => _currentIndex = index);
    }
  }

  /// 🔄 Carga listas desde repos y mantiene List<Map> para no romper pantallas existentes
  Future<void> fetchData() async {
    // Accounts
    final accs = await _accountsRepo.getAll(); // List<Account>
    final accMaps = accs.map<Map<String, dynamic>>((Account a) => a.toMap()).toList();

    // Categories
    final cats = await _categoriesRepo.getAll(); // List<model.Category>
    final catMaps = cats.map<Map<String, dynamic>>((model.Category c) => c.toMap()).toList();

    // Transactions
    final txs = await _txRepo.all(); // List<AppTransaction>
    final txMaps = txs.map<Map<String, dynamic>>((AppTransaction t) => t.toMap()).toList();

    setState(() {
      _accounts = accMaps;
      _categories = catMaps;
      _transactions = txMaps;
    });
  }

  @override
  Widget build(BuildContext context) {
    // (sin "_" para que el analizador no se queje por ser local)
    final List<Widget> pages = [
      DashboardScreen(
        key: _dashboardKey,
        accounts: _accounts,
        categories: _categories,
        transactions: _transactions,
      ),
      const ReportsScreen(),
      const SizedBox(), // slot del FAB
      AccountsScreen(
        key: _accountsKey,
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 4,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: _currentIndex == 0 ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: () => _onTabTapped(0),
            ),
            IconButton(
              icon: Icon(
                Icons.bar_chart,
                color: _currentIndex == 1 ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: () => _onTabTapped(1),
            ),
            const SizedBox(width: 40), // espacio del FAB
            IconButton(
              icon: Icon(
                Icons.account_balance_wallet,
                color: _currentIndex == 3 ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: () => _onTabTapped(3),
            ),
            IconButton(
              icon: Icon(
                Icons.settings,
                color: _currentIndex == 4 ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: () => _onTabTapped(4),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTapped(2),
        backgroundColor: Theme.of(context).primaryColor,
        shape: const CircleBorder(),
        elevation: 15,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
