import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart'; // 📌 Importamos AppColors

class CategorySelector extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final String transactionType;
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
  _CategorySelectorState createState() => _CategorySelectorState();
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
                  ? widget.categories.firstWhere(
                    (cat) => cat['id'] == selectedCategory,
                orElse: () => {'name': 'unknown_category'.tr()},
              )['name']
                  : "select_category".tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Icon(Icons.arrow_drop_down, size: 24, color: Theme.of(context).iconTheme.color),
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
                      Text(
                        "category".tr(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: Theme.of(context).iconTheme.color,
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
                              title: Text(
                                category['name'],
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              trailing: subcategories.isNotEmpty
                                  ? IconButton(
                                icon: Icon(isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more),
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
                                    title: Text(
                                      sub['name'],
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
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
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _addNewCategory,
                    icon: const Icon(Icons.add),
                    label: Text("add_category".tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
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
