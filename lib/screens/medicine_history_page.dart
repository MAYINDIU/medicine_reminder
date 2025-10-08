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
  List<Medicine> _allMedicines = [];
  List<Medicine> _pendingMedicines = [];
  List<Medicine> _completedMedicines = [];

  // Theme Colors
  final Color _primaryAppColor = Colors.teal.shade600;
  final Color _accentColor = Colors.indigo.shade400;
  final Color _completedColor = Colors.green.shade600;
  final Color _pendingColor = Colors.orange.shade700;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    final fetchedMedicines = await _db.getUserMedicines(widget.userId);
    
    // Reset lists
    _pendingMedicines = [];
    _completedMedicines = [];
    
    final now = DateTime.now();

    for (var med in fetchedMedicines) {
      if (med.scheduleDateTime.isBefore(now)) {
        _completedMedicines.add(med);
      } else {
        _pendingMedicines.add(med);
      }
    }

    // Sort: Pending (closest first), Completed (most recent first)
    _pendingMedicines.sort((a, b) => a.scheduleDateTime.compareTo(b.scheduleDateTime));
    _completedMedicines.sort((a, b) => b.scheduleDateTime.compareTo(a.scheduleDateTime));
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteMedicine(Medicine med) async {
    // 1. Cancel Notifications (using the IDs you defined)
    // NOTE: If you only use med.id! for the main notification, you only need to cancel that one. 
    // I'm keeping your original logic for safety, assuming you have multiple related notifications.
    await NotificationService().cancelNotification(med.id!); // Main notification
    await NotificationService().cancelNotification(med.id! * 10);
    await NotificationService().cancelNotification(med.id! * 10 + 1);
    await NotificationService().cancelNotification(med.id! * 10 + 2);
    
    // 2. Delete from DB
    await _db.deleteMedicine(med.id!);
    
    // 3. Update UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${med.name} reminder deleted."),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    _loadHistory();
  }
  
  // Widget to build the individual medicine card with design
  Widget _buildMedicineCard(Medicine med, bool isPast) {
    Color statusColor = isPast ? _completedColor : _pendingColor;
    IconData statusIcon = isPast ? Icons.check_circle_outline : Icons.alarm_on_outlined;

    return Dismissible(
      key: Key(med.id!.toString()), 
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: const Text("Confirm Deletion"),
              content: Text("Are you sure you want to permanently delete the reminder for ${med.name}?"),
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
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: isPast ? BorderSide.none : BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.all(15),
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          title: Text(
            med.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: isPast ? Colors.black87 : _primaryAppColor,
              decoration: isPast ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              // Formatted Date and Time
              Text(
                'Scheduled: ${DateFormat('hh:mm a, MMM d, yyyy').format(med.scheduleDateTime)}',
                style: TextStyle(
                  color: isPast ? Colors.grey.shade600 : statusColor, 
                  fontWeight: isPast ? FontWeight.normal : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (med.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                // Description
                Text(
                  'Notes: ${med.description}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                ),
              ]
            ],
          ),
          trailing: isPast ? Icon(Icons.history, color: Colors.grey) : Icon(Icons.arrow_forward_ios, color: Colors.grey.shade300, size: 16),
        ),
      ),
    );
  }
  
  // Widget to display the medicine list for a specific category
  Widget _buildMedicineList(List<Medicine> list, bool isPast) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 50.0),
          child: CircularProgressIndicator(color: _primaryAppColor),
        ),
      );
    }
    
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isPast ? Icons.check_circle_outline : Icons.alarm_off, 
                size: 80, 
                color: isPast ? _completedColor.withOpacity(0.5) : _pendingColor.withOpacity(0.5)),
              const SizedBox(height: 10),
              Text(
                isPast ? "No past medicines recorded." : "No upcoming reminders found.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                isPast ? "Check back after your scheduled time passes." : "Add a new reminder from the Home Page.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      itemCount: list.length,
      itemBuilder: (_, index) {
        final med = list[index];
        return _buildMedicineCard(med, isPast);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            "Medicine Reminders",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: _primaryAppColor,
          elevation: 4,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            indicatorColor: _accentColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                icon: const Icon(Icons.schedule),
                text: "Pending (${_pendingMedicines.length})",
              ),
              Tab(
                icon: const Icon(Icons.done_all),
                text: "Completed (${_completedMedicines.length})",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Pending Medicines
            _buildMedicineList(_pendingMedicines, false),
            
            // Tab 2: Completed Medicines
            _buildMedicineList(_completedMedicines, true),
          ],
        ),
      ),
    );
  }
}