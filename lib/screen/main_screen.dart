import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'dashboard_screen.dart';
import 'reports_screen.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';
import 'add_transaction_screen.dart';

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

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late List<Map<String, dynamic>> _accounts;
  late List<Map<String, dynamic>> _categories;
  late List<Map<String, dynamic>> _transactions;

  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<AccountsScreenState> _accountsKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _accounts = List<Map<String, dynamic>>.from(widget.accounts);
    _categories = List<Map<String, dynamic>>.from(widget.categories);
    _transactions = List<Map<String, dynamic>>.from(widget.transactions);
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

  void _onTabTapped(int index) async {
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
        _accountsKey.currentState?.reloadAccounts(); // 👈 ACTUALIZA cuentas también
        setState(() => _currentIndex = 0); // Regresar a dashboard
      }
    } else {
      setState(() => _currentIndex = index);
    }
  }

  Future<void> fetchData() async {
    final db = DatabaseHelper();
    final updatedAccounts = await db.getAccounts();
    final updatedTransactions = await db.getTransactions();
    final updatedCategories = await db.getCategories();

    setState(() {
      _accounts = updatedAccounts;
      _transactions = updatedTransactions;
      _categories = updatedCategories;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      DashboardScreen(
        key: _dashboardKey,
        accounts: _accounts,
        categories: _categories,
        transactions: _transactions,
      ),
      ReportsScreen(),
      const SizedBox(),
      AccountsScreen(
        key: _accountsKey, // 👈 Aquí pasamos el key
      ),
      SettingsScreen(),
    ];

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 4,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => _onTabTapped(0),
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => _onTabTapped(1),
            ),
            const SizedBox(width: 40),
            IconButton(
              icon: const Icon(Icons.account_balance_wallet),
              onPressed: () => _onTabTapped(3),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _onTabTapped(4),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTapped(2),
        shape: const CircleBorder(),
        elevation: 15,
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.red,
      ),
    );
  }
}
