import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ManageAccountsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts; // demo: lista in-memory

  const ManageAccountsScreen({super.key, required this.accounts});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  late List<Map<String, dynamic>> _local; // copia local para testing

  @override
  void initState() {
    super.initState();
    _local = [...widget.accounts];
  }

  Future<void> _add() async {
    final name = await _askName(context, 'add'.tr());
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      final newId = (_local.isEmpty ? 1 : (_local.map((e) => e['id'] as int).reduce((a,b)=>a>b?a:b)+1));
      _local.add({'id': newId, 'name': name.trim()});
    });
  }

  Future<void> _rename(Map<String,dynamic> acc) async {
    final name = await _askName(context, 'edit'.tr(), initial: acc['name']);
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      final idx = _local.indexWhere((e) => e['id'] == acc['id']);
      if (idx != -1) _local[idx] = {..._local[idx], 'name': name.trim()};
    });
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('delete'.tr()),
        content: Text('are_you_sure'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('delete'.tr())),
        ],
      ),
    );
    if (ok == true) setState(() => _local.removeWhere((e) => e['id'] == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('manage_accounts'.tr()),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ],
      ),
      body: ListView.separated(
        itemCount: _local.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final acc = _local[i];
          return ListTile(
            title: Text(acc['name']),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _rename(acc)),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(acc['id'] as int)),
            ]),
          );
        },
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, String title, {String? initial}) {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nombre de la cuenta'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text('save'.tr())),
      ],
    ),
  );
}
