import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/settings_helper.dart';
import '../services/exchange_rate_service.dart';

// Widgets existentes
import '../widgets/account_widgets.dart';
import '../widgets/balance_section.dart';

// Pantallas
import 'account_detail_screen.dart';
import 'account_editor_screen.dart';

// Modelos / Repos
import '../models/account.dart';
import '../models/category.dart';
import '../models/account_group.dart';

import '../repositories/accounts_repository.dart';
import '../repositories/categories_repository.dart';
import '../repositories/account_groups_repository.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  final _accountsRepo = AccountsRepository();
  final _categoriesRepo = CategoriesRepository();
  final _groupsRepo = AccountGroupsRepository();

  String mainCurrency = 'DOP';

  // Trabajamos internamente con modelos
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<AccountGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';
    await _reload();
  }

  Future<void> _reload() async {
    final accounts = await _accountsRepo.getAll();
    final categories = await _categoriesRepo.getAll();
    final groups = await _groupsRepo.getAll();

    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _categories = categories;
      _groups = groups;
    });
  }

  void reloadAccounts() => _reload();

  // -------------------- Helpers de totales --------------------

  Future<double> _convert(double amount, String currency) =>
      ExchangeRateService.localConvert(amount, currency, mainCurrency);

  /// Totales generales (sólo cuentas visibles + incluidas en balance)
  Future<List<double>> _generalTotals() async {
    double inc = 0.0;
    double exp = 0.0;

    for (final a in _accounts) {
      if (a.visible == 1 && a.includeInBalance == 1) {
        final converted = await _convert(a.balance, a.currency);
        // No forzamos signo: dejamos el saldo tal cual y sumamos
        if (converted >= 0) {
          inc += converted;
        } else {
          exp += converted; // negativo
        }
      }
    }
    final total = inc + exp;
    return [inc, exp, total];
  }

  /// Total por grupo (muestra saldo sumado de cuentas visibles)
  Future<double> _groupTotal(List<Account> groupAccounts) async {
    double total = 0.0;
    for (final a in groupAccounts) {
      if (a.visible == 1) {
        total += await _convert(a.balance, a.currency);
      }
    }
    return total;
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    // Mapa id->nombre de grupos y nombre por defecto si es null
    final Map<int, String> groupNameById = {
      for (final g in _groups) g.id!: g.name,
    };
    const defaultGroupName = 'General';

    // Agrupar cuentas por nombre de grupo
    final Map<String, List<Account>> groupMap = {};
    for (final a in _accounts) {
      final name = (a.groupId != null)
          ? (groupNameById[a.groupId!] ?? defaultGroupName)
          : defaultGroupName;
      groupMap.putIfAbsent(name, () => []).add(a);
    }

    // Para widgets que todavía esperan Map en navegación
    List<Map<String, dynamic>> _accountsAsMaps(List<Account> list) =>
        list.map((a) => a.toMap()).toList();
    final categoriesMaps = _categories.map((c) => c.toMap()).toList();
    final allAccountsMaps = _accountsAsMaps(_accounts);

    return Scaffold(
      appBar: AppBar(
        title: Text('accounts'.tr(), style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Si luego agregas modo edición/ordenar grupos, ponlo aquí
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountEditorScreen()),
              );
              if (changed == true) _reload();
            },
          ),
        ],
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          children: [
            // Resumen general
            FutureBuilder<List<double>>(
              future: _generalTotals(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final inc = snap.data![0];
                final exp = snap.data![1];
                final total = snap.data![2];

                return BalanceSection(
                  totalIncome: inc,
                  totalExpenses: exp,
                  totalBalance: total,
                  title: 'accounts_summary'.tr(),
                  mainCurrency: mainCurrency,
                );
              },
            ),
            const SizedBox(height: 8),

            // Secciones por grupo
            ...groupMap.entries.map((entry) {
              final groupName = entry.key;
              final accountsInGroup = entry.value;
              final visible = accountsInGroup.where((a) => a.visible == 1).toList();

              return FutureBuilder<double>(
                future: _groupTotal(accountsInGroup),
                builder: (context, snap) {
                  final groupBalance = snap.data ?? 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Puedes seguir usando tu header actual (cambia el label “category” por “group”)
                      AccountCategoryHeader(
                        category: groupName, // título de sección
                        totalBalance: groupBalance,
                        isHidden: visible.isEmpty,
                        mainCurrency: mainCurrency,
                      ),

                      // Tiles por cuenta
                      ...accountsInGroup.map((a) {
                        if (a.type == 'credit') {
                          final remainingCredit = (a.maxCredit ?? 0) - (a.balance);
                          return CreditCardTile(
                            name: a.name,
                            dueAmount: a.balance,
                            remainingCredit: remainingCredit,
                            currency: a.currency,
                            visible: a.visible == 1,
                            onTap: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountDetailScreen(
                                    accountId: a.id!,
                                    accountName: a.name,
                                    accountCurrency: a.currency,
                                    accounts: allAccountsMaps,
                                    categories: categoriesMaps,
                                  ),
                                ),
                              );
                              if (changed == true) _reload();
                            },
                          );
                        } else {
                          return AccountTile(
                            name: a.name,
                            balance: a.balance,
                            currency: a.currency,
                            visible: a.visible == 1,
                            onTap: () async {
                              final changed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountDetailScreen(
                                    accountId: a.id!,
                                    accountName: a.name,
                                    accountCurrency: a.currency,
                                    accounts: allAccountsMaps,
                                    categories: categoriesMaps,
                                  ),
                                ),
                              );
                              if (changed == true) _reload();
                            },
                          );
                        }
                      }).toList(),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
