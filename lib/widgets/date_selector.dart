import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatefulWidget {
  final DateTime initialDate;
  final String initialFilter;
  final Function(DateTime, String) onDateChanged; // Función de callback para enviar la fecha y filtro actualizados

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

  /// 📌 Formatea la fecha según el filtro actual
  String _formatDate(DateTime date, String filter) {
    if (filter == 'Diaria') {
      return DateFormat('d MMM yyyy').format(date); // Ejemplo: 19 Mar 2025
    } else if (filter == 'Semanal') {
      DateTime startWeek = date.subtract(Duration(days: date.weekday - 1));
      DateTime endWeek = startWeek.add(const Duration(days: 6));
      return "${DateFormat('d/MM').format(startWeek)} ~ ${DateFormat('d/MM').format(endWeek)}";
    } else if (filter == 'Calendario') {
      return DateFormat('MMMM yyyy').format(date); // Ejemplo: Marzo 2025
    } else {
      return DateFormat('yyyy').format(date); // Ejemplo: 2025
    }
  }

  /// 📌 Método para seleccionar una nueva fecha desde el calendario
  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
      widget.onDateChanged(selectedDate, selectedFilter);
    }
  }

  /// 📌 Método para cambiar el filtro
  void _changeFilter(String filter) {
    setState(() {
      selectedFilter = filter;
    });
    widget.onDateChanged(selectedDate, selectedFilter);
  }

  /// 📌 Método para cambiar la fecha con las flechas
  void _changeDate(bool next) {
    setState(() {
      if (selectedFilter == 'Diaria') {
        selectedDate = selectedDate.add(Duration(days: next ? 1 : -1));
      } else if (selectedFilter == 'Semanal') {
        selectedDate = selectedDate.add(Duration(days: next ? 7 : -7));
      } else if (selectedFilter == 'Calendario') {
        selectedDate = DateTime(selectedDate.year, selectedDate.month + (next ? 1 : -1), 1);
      } else {
        selectedDate = DateTime(selectedDate.year + (next ? 1 : -1), 1, 1);
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
              onPressed: () => _changeDate(false),
            ),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Text(
                _formatDate(selectedDate, selectedFilter),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeDate(true),
            ),
          ],
        ),
        /// 📌 Selector de filtro (Diaria, Semanal, Calendario, Anual)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['Diaria', 'Semanal', 'Calendario', 'Anual'].map((filter) {
            return GestureDetector(
              onTap: () => _changeFilter(filter),
              child: Column(
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selectedFilter == filter ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (selectedFilter == filter)
                    Container(
                      height: 3,
                      width: 50,
                      color: Colors.red, // Línea roja debajo del seleccionado
                    ),
                ],
              ),
            );
          }).toList(),
        ),

      ],
    );
  }
}
