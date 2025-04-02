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
    if (filter == 'Quincenal') {
      int lastDay = DateTime(date.year, date.month + 1, 0).day;

      if (date.day <= 15) {
        return '1 - 15 ${DateFormat('MMM yyyy').format(date)}';
      } else {
        return '16 - $lastDay ${DateFormat('MMM yyyy').format(date)}';
      }
    } else if (filter == 'Mensual') {
      return DateFormat('MMMM yyyy').format(date);
    } else if (filter == 'Calendario') {
      return DateFormat('MMMM yyyy').format(date);
    } else {
      return DateFormat('yyyy').format(date);
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
      if (selectedFilter == 'Quincenal') {
        if (selectedDate.day <= 15) {
          // Si estás en la primera quincena y vas atrás → ir a la segunda quincena del mes anterior
          if (!next) {
            DateTime prevMonth = DateTime(selectedDate.year, selectedDate.month - 1, 16);
            selectedDate = prevMonth;
          } else {
            // Primera quincena → pasar a segunda quincena del mismo mes
            selectedDate = DateTime(selectedDate.year, selectedDate.month, 16);
          }
        } else {
          // Si estás en la segunda quincena
          if (next) {
            // Segunda quincena → ir a primera del mes siguiente
            selectedDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
          } else {
            // Segunda quincena → volver a primera del mismo mes
            selectedDate = DateTime(selectedDate.year, selectedDate.month, 1);
          }
        }
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
          children: ['Quincenal', 'Mensual', 'Calendario', 'Anual'].map((filter) {
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
