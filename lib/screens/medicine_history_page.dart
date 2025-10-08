import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';

class MedicineHistoryPage extends StatefulWidget {
  final int userId;
  const MedicineHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<MedicineHistoryPage> createState() => _MedicineHistoryPageState();
}

class _MedicineHistoryPageState extends State<MedicineHistoryPage> {
  final _db = DBHelper();
  List<Medicine> _medicines = [];
  final Color _primaryAppColor = Colors.teal.shade600;
  final Color _accentColor = Colors.indigo.shade400;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    // Show a loading state while fetching data
    setState(() {
      _medicines = [];
    });
    
    final fetchedMedicines = await _db.getUserMedicines(widget.userId);
    // Sort by scheduled date (most recent first)
    fetchedMedicines.sort((a, b) => b.scheduleDateTime.compareTo(a.scheduleDateTime));
    
    setState(() {
      _medicines = fetchedMedicines;
    });
  }

  Future<void> _deleteMedicine(Medicine med) async {
    // 1. Cancel Notifications
    await NotificationService().cancelNotification(med.id! * 10);
    await NotificationService().cancelNotification(med.id! * 10 + 1);
    await NotificationService().cancelNotification(med.id! * 10 + 2);
    
    // 2. Delete from DB
    await _db.deleteMedicine(med.id!);
    
    // 3. Update UI instantly (no need to reload all, but we'll stick to _loadHistory for simplicity)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${med.name} reminder deleted."),
        backgroundColor: Colors.red.shade700,
      ),
    );
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "My Medicine Reminders",
          style: TextStyle(
            color: _primaryAppColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: _primaryAppColor),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_medicines.isEmpty) {
      // Show loading indicator if data is still being fetched
      if (_medicines.isEmpty && mounted) {
        return Center(
          child: CircularProgressIndicator(color: _primaryAppColor),
        );
      }
      
      // Show empty state if no records are found after loading
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
              SizedBox(height: 10),
              Text(
                "No active or past medicine records found.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              SizedBox(height: 5),
              Text(
                "Add a new medication to see its history here.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    // Display the list of medicines
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      itemCount: _medicines.length,
      itemBuilder: (_, index) {
        final med = _medicines[index];
        
        return Dismissible(
          key: Key(med.id!.toString()), // Unique key required for Dismissible
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Confirm Deletion"),
                  content: Text("Are you sure you want to delete the reminder for ${med.name}?"),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("CANCEL", style: TextStyle(color: _primaryAppColor)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("DELETE", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            _deleteMedicine(med);
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                radius: 30,
                backgroundColor: _accentColor.withOpacity(0.1),
                child: Icon(Icons.medication_liquid, color: _primaryAppColor, size: 30),
              ),
              title: Text(
                med.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  // Formatted Date and Time
                  Text(
                    'Time: ${DateFormat('hh:mm a, MMM d, yyyy').format(med.scheduleDateTime)}',
                    style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 3),
                  // Description
                  Text(
                    med.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }
}