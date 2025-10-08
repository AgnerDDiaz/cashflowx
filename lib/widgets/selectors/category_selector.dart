// widgets/selectors/category_selector.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../screen/manage_categories_screen.dart'; // <-- importa la nueva pantalla

class CategorySelector extends StatefulWidget {
  final List<Map<String, dynamic>> categories;          // [{id,name,type,parent_id}, ...]
  final String transactionType;                          // "expense" | "income"
  final Function(int) onSelect;
  final int? initialSelectedId;

  const CategorySelector({
    Key? key,
    required this.categories,
    required this.transactionType,
    required this.onSelect,
    this.initialSelectedId,
  }) : super(key: key);

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  int? selectedCategory;
  int? expandedCategory;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialSelectedId;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showCategoryModal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedCategory != null
                  ? (widget.categories.firstWhere(
                    (cat) => cat['id'] == selectedCategory,
                orElse: () => {'name': 'unknown_category'.tr()},
              )['name'] as String)
                  : "select_category".tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Icon(Icons.arrow_drop_down,
                size: 24, color: Theme.of(context).iconTheme.color),
          ],
        ),
      ),
    );
  }

  void _showCategoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateModal) {
          final filtered = widget.categories
              .where((c) => c['type'] == widget.transactionType)
              .toList();
          final mains = filtered.where((c) => c['parent_id'] == null).toList();
          final textColor = Theme.of(context).textTheme.titleLarge?.color;

          return Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                // Header con título + ✎ (misma tonalidad que el texto: negro/blanco según tema)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("category".tr(),
                        style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.edit),   // ← ✎
                      color: textColor,               // ← mismo color que el texto (oscuro/claro)
                      tooltip: 'edit'.tr(),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManageCategoriesScreen(
                              initialType: widget.transactionType,
                              // para el demo pasamos las categorías actuales
                              categories: widget.categories,
                            ),
                          ),
                        );
                        // al volver simplemente cerramos el modal o recargamos si quieres
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: mains.map((cat) {
                      final subs = filtered
                          .where((s) => s['parent_id'] == cat['id'])
                          .toList();
                      final isExpanded = expandedCategory == cat['id'];

                      return Column(children: [
                        ListTile(
                          title: Text(cat['name'],
                              style: Theme.of(context).textTheme.bodyLarge),
                          trailing: subs.isNotEmpty
                              ? IconButton(
                            icon: Icon(isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more),
                            onPressed: () {
                              setStateModal(() {
                                expandedCategory =
                                isExpanded ? null : cat['id'];
                              });
                            },
                          )
                              : null,
                          onTap: () {
                            setState(() {
                              selectedCategory = cat['id'];
                              expandedCategory = null;
                            });
                            widget.onSelect(cat['id']);
                            Navigator.pop(context);
                          },
                        ),
                        if (isExpanded)
                          ...subs.map((sub) => Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: ListTile(
                              title: Text(sub['name'],
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                              onTap: () {
                                setState(() {
                                  selectedCategory = sub['id'];
                                });
                                widget.onSelect(sub['id']);
                                Navigator.pop(context);
                              },
                            ),
                          )),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
