// screen/manage_categories_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ManageCategoriesScreen extends StatefulWidget {
  final String initialType; // "expense" | "income"
  final List<Map<String, dynamic>> categories;

  const ManageCategoriesScreen({
    super.key,
    required this.initialType,
    required this.categories,
  });

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType == "income" ? 1 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses =
    widget.categories.where((c) => c['type'] == 'expense').toList();
    final incomes =
    widget.categories.where((c) => c['type'] == 'income').toList();

    List<Map<String, dynamic>> mainsOf(List<Map<String, dynamic>> list) =>
        list.where((c) => c['parent_id'] == null).toList();

    List<Map<String, dynamic>> subsOf(
        List<Map<String, dynamic>> list, int parentId) =>
        list.where((c) => c['parent_id'] == parentId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('manage_categories'.tr()),
        bottom: TabBar(
          controller: _tab,
          tabs: [Tab(text: 'expenses'.tr()), Tab(text: 'income'.tr())],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Gastos
          ListView(
            children: [
              for (final m in mainsOf(expenses))
                ExpansionTile(
                  title: Text(m['name']),
                  children: [
                    for (final s in subsOf(expenses, m['id'] as int))
                      ListTile(
                        title: Text(s['name']),
                        leading: const SizedBox(width: 8),
                      ),
                  ],
                ),
            ],
          ),
          // Ingresos
          ListView(
            children: [
              for (final m in mainsOf(incomes))
                ExpansionTile(
                  title: Text(m['name']),
                  children: [
                    for (final s in subsOf(incomes, m['id'] as int))
                      ListTile(
                        title: Text(s['name']),
                        leading: const SizedBox(width: 8),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
