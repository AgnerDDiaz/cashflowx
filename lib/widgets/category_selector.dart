import 'package:flutter/material.dart';

class CategorySelector extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final String transactionType;
  final Function(int) onSelect;
  final int? initialSelectedId; // ✅ NUEVO

  const CategorySelector({
    Key? key,
    required this.categories,
    required this.transactionType,
    required this.onSelect,
    this.initialSelectedId, // ✅ NUEVO
  }) : super(key: key);

  @override
  _CategorySelectorState createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  int? selectedCategory;
  int? expandedCategory;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialSelectedId; // ✅ Inicializamos si viene valor
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showCategoryModal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedCategory != null
                  ? widget.categories.firstWhere(
                    (cat) => cat['id'] == selectedCategory,
                orElse: () => {'name': 'Categoría desconocida'},
              )['name']
                  : "Seleccionar Categoría",
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.arrow_drop_down, size: 24, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCategoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            List<Map<String, dynamic>> filteredCategories = widget.categories
                .where((cat) => cat['type'] == widget.transactionType)
                .toList();

            List<Map<String, dynamic>> mainCategories =
            filteredCategories.where((cat) => cat['parent_id'] == null).toList();

            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Categoría", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: mainCategories.map((category) {
                        List<Map<String, dynamic>> subcategories = filteredCategories
                            .where((sub) => sub['parent_id'] == category['id'])
                            .toList();

                        bool isExpanded = expandedCategory == category['id'];

                        return Column(
                          children: [
                            ListTile(
                              title: Text(category['name'], style: const TextStyle(fontSize: 16)),
                              trailing: subcategories.isNotEmpty
                                  ? IconButton(
                                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                onPressed: () {
                                  setStateModal(() {
                                    expandedCategory = isExpanded ? null : category['id'];
                                  });
                                },
                              )
                                  : null,
                              onTap: () {
                                setState(() {
                                  selectedCategory = category['id'];
                                  expandedCategory = null;
                                });
                                widget.onSelect(category['id']);
                                Navigator.pop(context);
                              },
                            ),
                            if (isExpanded)
                              ...subcategories.map((sub) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 32.0),
                                  child: ListTile(
                                    title: Text(sub['name'], style: const TextStyle(fontSize: 14)),
                                    onTap: () {
                                      setState(() {
                                        selectedCategory = sub['id'];
                                      });
                                      widget.onSelect(sub['id']);
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              }).toList(),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addNewCategory,
                    icon: const Icon(Icons.add),
                    label: const Text("Añadir Categoría"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addNewCategory() {
    // Aquí iría la lógica para añadir nueva categoría
  }
}
