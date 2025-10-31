import 'package:flutter/material.dart';
import '../models/account_group.dart' show AccountGroup;
import '../repositories/account_groups_repository.dart' as groups_repo;

class GroupsReorderScreen extends StatefulWidget {
  final List<AccountGroup> groups;
  const GroupsReorderScreen({super.key, required this.groups});

  @override
  State<GroupsReorderScreen> createState() => _GroupsReorderScreenState();
}

class _GroupsReorderScreenState extends State<GroupsReorderScreen> {
  late List<AccountGroup> _list;
  final _repo = groups_repo.AccountGroupsRepository();

  @override
  void initState() { super.initState(); _list = List.of(widget.groups); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordenar grupos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              final orderedIds = _list.map((g) => g.id!).toList();
              await _repo.reorder(orderedIds);
              if (!mounted) return; Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: _list.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _list.removeAt(oldIndex);
            _list.insert(newIndex, item);
          });
        },
        itemBuilder: (_, i) {
          final g = _list[i];
          return ListTile(
            key: ValueKey(g.id),
            title: Text(g.name),
            trailing: const Icon(Icons.drag_indicator),
          );
        },
      ),
    );
  }
}