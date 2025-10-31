import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/totals_calculator.dart';
import '../widgets/balance_section.dart';
import '../widgets/account_group_section.dart';

import '../models/account_group.dart' show AccountGroup;
import '../models/account.dart';

import '../repositories/accounts_repository.dart';
import '../repositories/account_groups_repository.dart' as groups_repo;

import '../utils/settings_helper.dart';

import 'account_detail_screen.dart';
import 'account_editor_screen.dart';
import 'groups_reorder_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  AccountsScreenState createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  final _accountsRepo = AccountsRepository();
  final _groupsRepo = groups_repo.AccountGroupsRepository();
  bool _editMode = false;

  String mainCurrency = 'DOP';
  List<Account> _accounts = [];
  List<AccountGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  void reloadAccounts() {
    _reload();
  }

  Future<void> _init() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';
    await _reload();
  }

  Future<void> _reload() async {
    final accs = await _accountsRepo.getAll();
    final groups = await _groupsRepo.allOrdered();
    if (!mounted) return;
    setState(() {
      _accounts = accs;
      _groups = groups;
    });
  }

  // --------- Callbacks de edición ---------

  Future<void> _onToggleInclude(Account a) async {
    final include = a.includeInBalance == 1 ? false : true;
    await _accountsRepo.toggleIncludeInBalance(accountId: a.id!, include: include);
    await _reload();
  }

  Future<void> _onDelete(Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text('¿Seguro que quieres eliminar "${a.name}"? Esta acción es permanente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await _accountsRepo.deleteAccount(a.id!);
    await _reload();
  }

  Future<int?> _pickGroup(int? currentGroupId) async {
    return await showDialog<int?>(
      context: context,
      builder: (_) {
        return SimpleDialog(
          title: const Text('Mover a grupo'),
          children: _groups.map((g) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, g.id),
              child: Row(
                children: [
                  if (g.id == currentGroupId) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(g.name),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _onMoveToGroup(Account a) async {
    final newGroupId = await _pickGroup(a.groupId);
    if (newGroupId == null || newGroupId == a.groupId) return;
    await _accountsRepo.moveToGroup(accountId: a.id!, groupId: newGroupId);
    await _reload();
  }

  Future<void> _onReorderConfirmed(AccountGroup g, List<int> newOrderIds) async {
    try {
      await _accountsRepo.updateSortOrdersInGroup(g.id!, newOrderIds);
      await _reload();
    } catch (_) {
      final others = _accounts.where((a) => (a.groupId ?? -1) != (g.id ?? -2)).toList();
      final reorderedInGroup = _accounts
          .where((a) => (a.groupId ?? -1) == (g.id ?? -2))
          .toList()
        ..sort((x, y) => newOrderIds.indexOf(x.id!).compareTo(newOrderIds.indexOf(y.id!)));
      setState(() {
        _accounts = [...others, ...reorderedInGroup];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('accounts'.tr()),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.close : Icons.edit),
            tooltip: _editMode ? 'Cerrar edición' : 'Editar',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Reordenar grupos',
            onPressed: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupsReorderScreen(groups: _groups)),
              );
              if (changed == true) _reload();
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
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          children: [
            FutureBuilder<(double inc, double exp, double total)>(
              future: TotalsCalculator.generalTotals(_accounts, mainCurrency),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final (inc, exp, total) = snap.data!;
                return BalanceSection(
                  title: 'accounts_summary'.tr(),
                  totalIncome: inc,
                  totalExpenses: exp,
                  totalBalance: total,
                  mainCurrency: mainCurrency,
                );
              },
            ),
            const SizedBox(height: 8),
            ..._groups.map((g) {
              final items = _accounts.where((a) => (a.groupId ?? -1) == (g.id ?? -2)).toList();
              return AccountGroupSection(
                group: g,
                accounts: items,
                mainCurrency: mainCurrency,
                editMode: _editMode,
                onTapAccount: (a) async {
                  if (_editMode) return;
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountDetailScreen(
                        accountId: a.id!,
                        accountName: a.name,
                        accountCurrency: a.currency,
                        accounts: _accounts.map((x) => x.toMap()).toList(),
                        categories: const [],
                      ),
                    ),
                  );
                  if (changed == true) _reload();
                },
                onToggleInclude: _onToggleInclude,
                onDelete: _onDelete,
                onMoveToGroup: _onMoveToGroup,
                onReorderConfirmed: (ids) => _onReorderConfirmed(g, ids),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
