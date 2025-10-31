import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/account_group.dart';
import '../repositories/account_groups_repository.dart';
import 'add_group_screen.dart';

class GroupsReorderScreen extends StatefulWidget {
  final List<AccountGroup> groups;
  const GroupsReorderScreen({super.key, required this.groups});

  @override
  State<GroupsReorderScreen> createState() => _GroupsReorderScreenState();
}

class _GroupsReorderScreenState extends State<GroupsReorderScreen> {
  late List<AccountGroup> _list;
  final _repo = AccountGroupsRepository();
  bool _editMode = false;

  /// Se pone en true al reordenar/crear/eliminar para notificar al volver.
  bool _dirty = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _list = List.of(widget.groups);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _persistOrderDebounced() {
    _markDirty();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final ids = _list.map((e) => e.id!).toList();
      await _repo.reorder(ids);
    });
  }

  Future<void> _refreshFromDb({bool markDirty = false}) async {
    final fresh = await _repo.allOrdered();
    setState(() {
      _list = fresh;
      if (markDirty) _dirty = true;
    });
  }

  Future<void> _deleteGroup(AccountGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm_delete_group'.tr()),
        content: Text('delete_group_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'delete'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await _repo.deleteAndMoveAccounts(g.id!);
    await _refreshFromDb(markDirty: true);
  }

  Future<bool> _onWillPop() async {
    // Devuelve si hubo cambios para que Accounts recargue.
    Navigator.pop(context, _dirty);
    return false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'order_groups'.tr(),
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onWillPop(),
          ),
          actions: [
            IconButton(
              tooltip: _editMode ? 'exit_edit'.tr() : 'edit'.tr(),
              icon: Icon(_editMode ? Icons.checklist_rtl : Icons.edit),
              onPressed: () => setState(() => _editMode = !_editMode),
            ),
            IconButton(
              tooltip: 'new_group'.tr(),
              icon: const Icon(Icons.add),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddGroupScreen()),
                );
                if (created == true) await _refreshFromDb(markDirty: true);
              },
            ),
          ],
        ),
        body: ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: _list.length,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: Transform.scale(scale: 1.02, child: child),
          ),
          onReorder: (oldIndex, newIndex) async {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _list.removeAt(oldIndex);
              _list.insert(newIndex, item);
            });
            _persistOrderDebounced(); // guarda automáticamente
          },
          itemBuilder: (context, i) {
            final g = _list[i];
            return _GroupCard(
              key: ValueKey('g_${g.id}'),
              group: g,
              index: i,
              editMode: _editMode,
              onDelete: () => _deleteGroup(g),
            );
          },
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final AccountGroup group;
  final bool editMode;
  final VoidCallback? onDelete;
  final int index;

  const _GroupCard({
    super.key,
    required this.group,
    required this.editMode,
    required this.index,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w600);

    // Card visual como las cuentas: usa cardColor, bordes y paddings suaves.
    return Card(
      key: key,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Botón de eliminar a la IZQUIERDA (solo en modo edición)
            if (editMode) ...[
              IconButton(
                tooltip: 'delete'.tr(),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: onDelete,
              ),
              const SizedBox(width: 4),
            ],

            // Nombre del grupo (ocupa el espacio central)
            Expanded(
              child: Text(
                group.name,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 8),

            // Handle de drag a la DERECHA (usa listener de reorder)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.0),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
