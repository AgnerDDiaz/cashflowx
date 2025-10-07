import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/scheduled_transaction.dart';
import '../repositories/scheduled_transactions_repository.dart';
import '../utils/app_colors.dart';
import '../utils/database_helper.dart';
import 'edit_scheduled_transaction_screen.dart';

class ScheduledTransactionsScreen extends StatefulWidget {
  const ScheduledTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledTransactionsScreen> createState() => _ScheduledTransactionsScreenState();
}

class _ScheduledTransactionsScreenState extends State<ScheduledTransactionsScreen> {
  final _repo = ScheduledTransactionsRepository();
  final _dbHelper = DatabaseHelper();
  final _fmt = DateFormat('yyyy-MM-dd');
  late Future<List<ScheduledTransaction>> _future;
  bool _editMode = false;

  /// Overrides locales para reflejo instantáneo (id -> isActive). Se limpian en cada _reload().
  final Map<int, bool> _activeOverrides = {};

  /// Cache de cuentas: id -> { 'name': String, 'currency': String, 'visible': int }
  final Map<int, Map<String, dynamic>> _accountsById = {};

  @override
  void initState() {
    super.initState();
    _future = _repo.all(orderBy: 'frequency ASC, type ASC, next_run ASC');
    _loadAccountsCache();
  }

  Future<void> _loadAccountsCache() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'accounts',
      columns: ['id', 'name', 'currency', 'visible'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    _accountsById
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(
        (r['id'] as num).toInt(),
        {'name': r['name'], 'currency': r['currency'], 'visible': r['visible']},
      )));
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    final data = await _repo.all(orderBy: 'frequency ASC, type ASC, next_run ASC');
    if (!mounted) return;
    _activeOverrides.clear(); // resetea overrides al sincronizar
    setState(() => _future = Future.value(data));
    await _loadAccountsCache(); // por si cambió un nombre
    // pequeño delay para que el RefreshIndicator complete su animación
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  String _freqTitle(String f) {
    switch (f.toLowerCase()) {
      case 'weekly':
        return tr('scheduled.freq_weekly');       // Trans. Semanales
      case 'biweekly':
        return tr('scheduled.freq_biweekly');     // Trans. Quincenales
      case 'monthly':
        return tr('scheduled.freq_monthly');      // Trans. Mensuales
      case 'quarterly':
        return tr('scheduled.freq_quarterly');    // Trans. Trimestrales
      case 'semiannual':
        return tr('scheduled.freq_semiannual');   // Trans. Semestrales
      case 'annual':
        return tr('scheduled.freq_annual');       // Trans. Anuales
      default:
        return tr('scheduled.freq_generic');      // Trans. Recurrentes
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width * 0.04; // responsive padding
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('scheduled.title')), // Transacciones Recurrentes
        actions: [
          IconButton(
            tooltip: _editMode ? tr('common.done_editing') : tr('common.edit'),
            icon: Icon(_editMode ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
          IconButton(
            tooltip: tr('common.add'),
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditScheduledTransactionScreen()),
              );
              if (result == true) _reload(); // recarga inmediata al volver
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<ScheduledTransaction>>(
          future: _future,
          builder: (context, snap) {
            // Hacemos el hijo SIEMPRE "scrollable" para que el pull-to-refresh funcione
            if (snap.connectionState != ConnectionState.done) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(pad),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 400),
                ],
              );
            }
            if (!snap.hasData || snap.data!.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(pad),
                children: [
                  const SizedBox(height: 32),
                  Center(child: Text(tr('scheduled.empty'))),
                ],
              );
            }

            final data = snap.data!;
            // Agrupar por frecuencia
            final Map<String, List<ScheduledTransaction>> byFreq = {};
            for (final s in data) {
              byFreq.putIfAbsent(s.frequency, () => []).add(s);
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(left: pad, right: pad, bottom: pad),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: byFreq.length,
              itemBuilder: (context, idx) {
                final entry = byFreq.entries.elementAt(idx);
                final freq = entry.key;
                final list = entry.value;

                final incomes = list.where((e) => e.type == 'income').toList();
                final expenses = list.where((e) => e.type == 'expense').toList();
                final transfers = list.where((e) => e.type == 'transfer').toList();

                // pista de moneda (si hay mezclas, usamos la primera disponible)
                final currencyHint = incomes.isNotEmpty
                    ? incomes.first.currency
                    : (expenses.isNotEmpty
                    ? expenses.first.currency
                    : (transfers.isNotEmpty ? transfers.first.currency : ''));

                return _FrequencyGroupCard(
                  // TÍTULO con onBackground (blanco/negro según tema)
                  title: _freqTitle(freq),
                  titleColor: theme.colorScheme.onBackground,
                  currencyHint: currencyHint,
                  incomes: incomes,
                  expenses: expenses,
                  transfers: transfers,
                  accountsById: _accountsById,
                  editMode: _editMode,
                  // Toggle con feedback instantáneo + persist + reload seguro
                  onToggleActive: (s) async {
                    if (s.id == null) return;
                    final currentEffective = _activeOverrides[s.id!] ?? (s.isActive == 1);
                    final newActive = !currentEffective;

                    // 1) feedback al instante
                    setState(() => _activeOverrides[s.id!] = newActive);

                    try {
                      // 2) persistir
                      await _repo.toggleActive(s.id!, newActive);
                    } catch (_) {
                      // si falla, revertimos override
                      setState(() => _activeOverrides[s.id!] = currentEffective);
                    } finally {
                      // 3) sincronizamos feed
                      await _reload();
                    }
                  },
                  onDelete: (s) async {
                    if (s.id == null) return;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(tr('scheduled.delete_title')),
                        content: Text(tr('scheduled.delete_body')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(tr('common.cancel')),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(tr('common.delete')),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      final deletedId = s.id!;
                      // feedback instantáneo
                      setState(() {
                        _activeOverrides.remove(deletedId);
                        _future = _future.then((list) {
                          final copy = List<ScheduledTransaction>.from(list);
                          copy.removeWhere((e) => e.id == deletedId);
                          return copy;
                        });
                      });
                      await _repo.delete(deletedId);
                      await _reload();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('scheduled.deleted_toast'))),
                      );
                    }
                  },
                  onOpen: (s) async {
                    if (_editMode) return;
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditScheduledTransactionScreen(transaction: s)),
                    );
                    if (result == true) _reload();
                  },
                  activeOverrides: _activeOverrides,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FrequencyGroupCard extends StatelessWidget {
  final String title;
  final Color titleColor;
  final String currencyHint;
  final List<ScheduledTransaction> incomes;
  final List<ScheduledTransaction> expenses;
  final List<ScheduledTransaction> transfers;
  final Map<int, Map<String, dynamic>> accountsById;
  final bool editMode;
  final Future<void> Function(ScheduledTransaction) onToggleActive;
  final Future<void> Function(ScheduledTransaction) onDelete;
  final Future<void> Function(ScheduledTransaction) onOpen;
  final Map<int, bool> activeOverrides;

  const _FrequencyGroupCard({
    Key? key,
    required this.title,
    required this.titleColor,
    required this.currencyHint,
    required this.incomes,
    required this.expenses,
    required this.transfers,
    required this.accountsById,
    required this.editMode,
    required this.onToggleActive,
    required this.onDelete,
    required this.onOpen,
    required this.activeOverrides,
  }) : super(key: key);

  bool _isActiveEff(ScheduledTransaction s) =>
      activeOverrides[s.id ?? -1] ?? (s.isActive == 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moneyFmt = NumberFormat.currency(symbol: currencyHint.isNotEmpty ? '$currencyHint ' : '');

    // Totales activos/inactivos por sección
    final expActiveTotal = expenses.where(_isActiveEff).fold<double>(0, (p, e) => p + e.amount);
    final expInactiveTotal = expenses.where((e) => !_isActiveEff(e)).fold<double>(0, (p, e) => p + e.amount);

    final incActiveTotal = incomes.where(_isActiveEff).fold<double>(0, (p, e) => p + e.amount);
    final incInactiveTotal = incomes.where((e) => !_isActiveEff(e)).fold<double>(0, (p, e) => p + e.amount);

    Widget sectionHeader({
      required String label,
      required int count,
      required double activeTotal,
      required double inactiveTotal,
      required Color colorActive,
    }) {
      final leftGrey = theme.textTheme.titleMedium?.copyWith(
        color: theme.disabledColor,
        fontWeight: FontWeight.w700,
      );
      final rightColor = theme.textTheme.titleMedium?.copyWith(
        color: colorActive,
        fontWeight: FontWeight.w700,
      );

      return Padding(
        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label ($count)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorActive, // título sección con color de kpi (igual que antes)
                ),
              ),
            ),
            if (inactiveTotal > 0) ...[
              Text(moneyFmt.format(inactiveTotal), style: leftGrey),
              const SizedBox(width: 10),
            ],
            Text(moneyFmt.format(activeTotal), style: rightColor),
          ],
        ),
      );
    }

    // Fondo transparente (sin “marco”)
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de frecuencia con onBackground (blanco/negro según tema)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  )),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 4),

          // Gastos
          if (expenses.isNotEmpty) ...[
            sectionHeader(
              label: tr('scheduled.expenses'),
              count: expenses.length,
              activeTotal: expActiveTotal,
              inactiveTotal: expInactiveTotal,
              colorActive: AppColors.gastoColor,
            ),
            ...expenses.map((s) => _ScheduledItemTile(
              s: s,
              color: AppColors.gastoColor,
              editMode: editMode,
              onToggleActive: onToggleActive,
              onDelete: onDelete,
              onOpen: onOpen,
              effectiveActive: _isActiveEff(s),
              accountsById: accountsById,
            )),
            const SizedBox(height: 8),
          ],

          // Ingresos
          if (incomes.isNotEmpty) ...[
            sectionHeader(
              label: tr('scheduled.incomes'),
              count: incomes.length,
              activeTotal: incActiveTotal,
              inactiveTotal: incInactiveTotal,
              colorActive: AppColors.ingresoColor,
            ),
            ...incomes.map((s) => _ScheduledItemTile(
              s: s,
              color: AppColors.ingresoColor,
              editMode: editMode,
              onToggleActive: onToggleActive,
              onDelete: onDelete,
              onOpen: onOpen,
              effectiveActive: _isActiveEff(s),
              accountsById: accountsById,
            )),
            const SizedBox(height: 8),
          ],

          // Transferencias
          if (transfers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(
                '${tr('scheduled.transfers')} (${transfers.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
            ),
            ...transfers.map((s) => _ScheduledItemTile(
              s: s,
              color: theme.hintColor,
              editMode: editMode,
              onToggleActive: onToggleActive,
              onDelete: onDelete,
              onOpen: onOpen,
              effectiveActive: _isActiveEff(s),
              accountsById: accountsById,
              isTransfer: true,
            )),
          ],
        ],
      ),
    );
  }
}

class _ScheduledItemTile extends StatelessWidget {
  final ScheduledTransaction s;
  final Color color;
  final bool editMode;
  final Future<void> Function(ScheduledTransaction) onToggleActive;
  final Future<void> Function(ScheduledTransaction) onDelete;
  final Future<void> Function(ScheduledTransaction) onOpen;

  /// Estado efectivo (override local o BD)
  final bool effectiveActive;

  /// Para imprimir "Cuenta A → Cuenta B" en transferencias
  final Map<int, Map<String, dynamic>> accountsById;

  /// Render especial para transferencias (icono gris y subtítulo con de→a)
  final bool isTransfer;

  const _ScheduledItemTile({
    Key? key,
    required this.s,
    required this.color,
    required this.editMode,
    required this.onToggleActive,
    required this.onDelete,
    required this.onOpen,
    required this.effectiveActive,
    required this.accountsById,
    this.isTransfer = false,
  }) : super(key: key);

  String _accName(int? id) {
    if (id == null) return '—';
    final m = accountsById[id];
    if (m == null) return '#$id';
    final name = (m['name'] as String?) ?? '#$id';
    final vis = (m['visible'] as int?) ?? 1;
    return vis == 1 ? name : '$name (${tr('common.hidden')})';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final baseBg = theme.cardColor;
    final inactiveBg = theme.colorScheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.22 : 0.35,
    );

    final icon = isTransfer
        ? Icons.swap_horiz
        : (s.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward);

    // Color del ícono:
    final iconColor = isTransfer
        ? theme.hintColor // siempre gris para transferencias
        : (effectiveActive ? color : theme.disabledColor);

    final titleText = isTransfer
        ? ((s.note?.isNotEmpty ?? false) ? s.note! : tr('scheduled.transfer'))
        : ((s.note?.isNotEmpty ?? false) ? s.note! : tr('scheduled.no_desc'));

    final amountLine = '${tr('scheduled.amount')}: ${s.amount.toStringAsFixed(2)} ${s.currency}';
    final nextLine = '${tr('scheduled.next_charge')}: ${s.nextRun}';
    final endLine = (s.endDate != null && s.endDate!.isNotEmpty) ? '${tr('scheduled.ends')}: ${s.endDate}' : null;
    final transferLine = isTransfer ? '${tr('scheduled.from_to', args: [_accName(s.accountId), _accName(s.linkedAccountId)])}' : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: effectiveActive ? baseBg : inactiveBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kElevationToShadow[1],
      ),
      child: InkWell(
        onTap: () => onOpen(s),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titleText, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  if (transferLine != null) ...[
                    Text(
                      transferLine,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    amountLine,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nextLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                    ),
                  ),
                  if (endLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      endLine,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (editMode) ...[
              IconButton(
                tooltip: effectiveActive ? tr('scheduled.hide') : tr('scheduled.show'),
                icon: Icon(effectiveActive ? Icons.visibility_off : Icons.visibility),
                color: effectiveActive ? theme.disabledColor : (isTransfer ? theme.hintColor : color),
                onPressed: () => onToggleActive(s),
              ),
              IconButton(
                tooltip: tr('common.delete'),
                icon: const Icon(Icons.delete_outline),
                color: AppColors.gastoColor,
                onPressed: () => onDelete(s),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
