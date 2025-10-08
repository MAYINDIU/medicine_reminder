import 'package:flutter/material.dart';
import '../models/medicine.dart';
import 'package:intl/intl.dart';

class MedicineCard extends StatelessWidget {
  final Medicine m;
  final VoidCallback? onDelete;
  final VoidCallback? onSchedule;

  const MedicineCard({super.key, required this.m, this.onDelete, this.onSchedule});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${m.dose} • ${DateFormat.jm().format(m.scheduleDateTime)} • ${m.frequency}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.alarm, color: Colors.blue), onPressed: onSchedule),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
