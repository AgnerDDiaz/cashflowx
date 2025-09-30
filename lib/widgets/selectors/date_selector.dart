import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart'; // 📌 Asegúrate de importar AppColors
import 'package:easy_localization/easy_localization.dart';


class DateSelector extends StatefulWidget {
  final DateTime initialDate;
  final String initialFilter;
  final Function(DateTime, String) onDateChanged;

  const DateSelector({
    Key? key,
    required this.initialDate,
    required this.initialFilter,
    required this.onDateChanged,
  }) : super(key: key);

  @override
  _DateSelectorState createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  late DateTime selectedDate;
  late String selectedFilter;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    selectedFilter = widget.initialFilter;
  }

  String _formatDate(DateTime date, String filter) {
    if (filter == 'weekly') {
      DateTime start = date.subtract(Duration(days: date.weekday - 1));
      DateTime end = start.add(const Duration(days: 6));
      return "${DateFormat('d/MM').format(start)} ~ ${DateFormat('d/MM').format(end)}";
    } else if (filter == 'monthly' || filter == 'calendar') {
      return DateFormat('MMMM yyyy').format(date);
    } else if (filter == 'annual') {
      return DateFormat('yyyy').format(date);
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context), // Respetamos el tema claro/oscuro
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
      widget.onDateChanged(selectedDate, selectedFilter);
    }
  }

  void _changeFilter(String filter) {
    setState(() {
      selectedFilter = filter;
    });
    widget.onDateChanged(selectedDate, selectedFilter);
  }

  void _changeDate(bool next) {
    setState(() {
      if (selectedFilter == 'weekly') {
        selectedDate = selectedDate.add(Duration(days: next ? 7 : -7));
      } else if (selectedFilter == 'monthly' || selectedFilter == 'calendar') {
        selectedDate = DateTime(
          selectedDate.year,
          selectedDate.month + (next ? 1 : -1),
          1,
        );
      } else if (selectedFilter == 'annual') {
        selectedDate = DateTime(
          selectedDate.year + (next ? 1 : -1),
          1,
          1,
        );
      }
    });

    widget.onDateChanged(selectedDate, selectedFilter);
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 📌 Selector de fecha con flechas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              color: Theme.of(context).iconTheme.color,
              onPressed: () => _changeDate(false),
            ),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Text(
                _formatDate(selectedDate, selectedFilter),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              color: Theme.of(context).iconTheme.color,
              onPressed: () => _changeDate(true),
            ),
          ],
        ),

        /// 📌 Selector de filtro (Semanal, Mensual, Calendario, Anual)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['weekly', 'monthly', 'calendar', 'annual'].map((filter) {
            final bool isSelected = selectedFilter == filter;
            return GestureDetector(
              onTap: () => _changeFilter(filter),
              child: Column(
                children: [
                  Text(
                    filter.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),

                  if (isSelected)
                    Container(
                      height: 3,
                      width: 50,
                      color: AppColors.primaryColor,
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
