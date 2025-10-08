import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Assuming these models and services are in your project structure
import '../models/user.dart';
import '../models/medicine.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';
import 'medicine_history_page.dart';
import 'profile_page.dart';
import 'package:smart_medicine_reminder_new/screens/login_page.dart';

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Enhanced Color Palette for a modern, calming look
  final MaterialColor _primarySwatch = Colors.blue;
  // --- UPDATED COLOR HERE ---
  final Color _primaryAppColor = Colors.teal.shade600; 
  // --------------------------
  final Color _accentColor = Colors.orange.shade400; // Used for emphasis
  final Color _backgroundColor = Colors.blueGrey.shade50;
  final Color _cardColor = Colors.white;

  final _db = DBHelper();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  
  // Separate lists for organization
  List<Medicine> _allMedicines = [];
  List<Medicine> _upcomingMedicines = [];
  
  // Value for the badge
  int _pendingCount = 0;

  // Initialize with a time slightly in the future
  DateTime _selectedDateTime = DateTime.now().add(const Duration(minutes: 5));
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    NotificationService().initNotification(); 
    _loadMedicines();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    _allMedicines = await _db.getUserMedicines(widget.user.id!);
    
    // 1. Filter and sort upcoming medicines
    final now = DateTime.now();
    _upcomingMedicines = _allMedicines
        .where((med) => med.scheduleDateTime.isAfter(now))
        .toList();
        
    // Sort by scheduled time, ascending (closest upcoming first)
    _upcomingMedicines.sort((a, b) => a.scheduleDateTime.compareTo(b.scheduleDateTime));
    
    // 2. Update pending count for the badge
    _pendingCount = _upcomingMedicines.length;
    
    setState(() {});
  }

  // Helper to pick Date and Time
  void _pickDateTime() async {
    DateTime now = DateTime.now();
    DateTime initialDate = _selectedDateTime.isAfter(now) ? _selectedDateTime : now.add(const Duration(minutes: 5));

    // 1. Pick Date
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryAppColor, // Header background color
              onPrimary: Colors.white, // Header text/icon color
              onSurface: Colors.black, // Calendar day text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primaryAppColor), // OK/Cancel button color
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    // 2. Pick Time
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryAppColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primaryAppColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    // 3. Update State
    DateTime newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    
    // Check if the selected time is in the past
    if (newDateTime.isBefore(now)) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Selected time is in the past. Please select a future time."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    setState(() {
      _selectedDateTime = newDateTime;
    });
  }

  void _addMedicine() async {
    String name = _nameController.text.trim();
    DateTime now = DateTime.now().subtract(const Duration(seconds: 1));

    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Medicine Name is required."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    if (_selectedDateTime.isBefore(now)) {
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select a future date and time."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    Medicine med = Medicine(
      userId: widget.user.id!,
      name: name,
      description: _descController.text.trim(),
      scheduleDateTime: _selectedDateTime,
    );

    // 1. Insert into DB
    med.id = await _db.insertMedicine(med);

    // 2. Schedule Notification
    await NotificationService().scheduleNotification(
      med.id!,
      "Time for your medication!", // More engaging title
      "It's time to take **${med.name}**! ${med.description.isNotEmpty ? 'Details: ${med.description}' : 'Don\'t forget!'}**",
      med.scheduleDateTime,
    );

    // 3. Text-to-Speech confirmation
    await _tts.speak(
      "Medicine ${med.name} reminder successfully scheduled for ${DateFormat('hh:mm a').format(med.scheduleDateTime)}",
    );

    // 4. Show Professional Success Dialog
    _showSuccessDialog(med);

    // 5. Reset input fields
    _nameController.clear();
    _descController.clear();
    setState(() {
      _selectedDateTime = DateTime.now().add(const Duration(minutes: 5));
    });

    // 6. Reload list
    _loadMedicines();
  }

  // PROFESSIONAL SUCCESS DIALOG (Omitted for brevity, but kept in the final code)
  void _showSuccessDialog(Medicine med) {
    // ... [Implementation for _showSuccessDialog is unchanged]
      showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: _cardColor,
          elevation: 10,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with a nice glow effect
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade50,
                ),
                child: Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "Reminder Activated!",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 15),
              // Detail rows
              _buildDetailRow(
                icon: Icons.medication_outlined,
                label: "Medicine:",
                value: med.name,
                valueStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: "Date:",
                value: DateFormat('MMM d, yyyy').format(med.scheduleDateTime),
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.access_time_outlined,
                label: "Time:",
                value: DateFormat('hh:mm a').format(med.scheduleDateTime),
                valueStyle: TextStyle(color: _accentColor, fontWeight: FontWeight.w600),
              ),
              if (med.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                  _buildDetailRow(
                  icon: Icons.description_outlined,
                  label: "Details:",
                  value: med.description,
                  valueStyle: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                "We'll notify you on time!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryAppColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Got It!",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        );
      },
    );
  }
  
  // Helper widget for the success dialog detail rows (Omitted for brevity, but kept in the final code)
  Widget _buildDetailRow({required IconData icon, required String label, required String value, TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _primaryAppColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }


  void _deleteMedicine(Medicine med) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              const Text("Confirm Deletion"),
            ],
          ),
          content: Text("Are you sure you want to delete \"${med.name}\"?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("Cancel", style: TextStyle(color: _primaryAppColor))),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _db.deleteMedicine(med.id!);
      NotificationService().cancelNotification(med.id!);
      _loadMedicines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Medicine \"${med.name}\" reminder deleted!"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _editMedicine(Medicine med) async {
    final _editNameController = TextEditingController(text: med.name);
    final _editDescController = TextEditingController(text: med.description);
    DateTime _tempEditDateTime = med.scheduleDateTime;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Edit Medicine Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _editNameController, decoration: const InputDecoration(labelText: "Medicine Name")),
                const SizedBox(height: 10),
                TextField(controller: _editDescController, decoration: const InputDecoration(labelText: "Description")),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: Text(DateFormat('MMM d, yyyy - hh:mm a').format(_tempEditDateTime))),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
                      icon: const Icon(Icons.edit_calendar, size: 18, color: Colors.white),
                      onPressed: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: _tempEditDateTime.isBefore(DateTime.now()) ? DateTime.now() : _tempEditDateTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate == null) return;

                        TimeOfDay? pickedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.fromDateTime(_tempEditDateTime),
                        );
                        if (pickedTime == null) return;

                        DateTime newDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );

                        if (newDateTime.isBefore(DateTime.now())) {
                          if (mounted) {
                              // Use the main context for the SnackBar
                             ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                              content: Text("Selected time is in the past."),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                          return;
                        }

                        setDialogState(() {
                          _tempEditDateTime = newDateTime;
                        });
                      },
                      label: const Text("Change Time", style: TextStyle(color: Colors.white)),
                    )
                  ],
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel", style: TextStyle(color: _primaryAppColor))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryAppColor),
                onPressed: () async {
                  if (_editNameController.text.trim().isEmpty) {
                      if(mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                          content: Text("Name cannot be empty."), 
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ));
                    return;
                  } else if (_tempEditDateTime.isBefore(DateTime.now())) {
                      if(mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                          content: Text("Time must be in the future."),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ));
                    return;
                  }

                  med.name = _editNameController.text.trim();
                  med.description = _editDescController.text.trim();
                  med.scheduleDateTime = _tempEditDateTime;
                  await _db.updateMedicine(med);

                  NotificationService().cancelNotification(med.id!);
                  await NotificationService().scheduleNotification(
                    med.id!,
                    "Time for your medication!",
                    "It's time to take **${med.name}**! ${med.description.isNotEmpty ? 'Details: ${med.description}' : 'Don\'t forget!'}**",
                    med.scheduleDateTime,
                  );

                  _loadMedicines();
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                      content: Text("Medicine \"${med.name}\" updated successfully!"),
                      backgroundColor: Colors.green.shade600,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // IMPROVED MEDICINE CARD DESIGN
  Widget _buildMedicineCard(Medicine med) {
    bool isPast = med.scheduleDateTime.isBefore(DateTime.now());
    
    // Choose icon and color based on status
    IconData icon = isPast ? Icons.check_circle_outline : Icons.alarm_on;
    Color iconColor = isPast ? Colors.green.shade400 : _primaryAppColor;
    
    // Use a lighter shade for past reminders for a cleaner look
    Color cardColor = isPast ? Colors.grey.shade100 : _cardColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: cardColor,
      elevation: isPast ? 1 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Icon(icon, color: iconColor, size: 30),
        title: Text(
          med.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isPast ? Colors.grey.shade600 : Colors.black87,
            // Only strike through if we're showing it here for some reason, 
            // but in the context of only showing UPCOMING, this shouldn't be needed.
            // I'm keeping the original logic for flexibility, but realize these are UPCOMING cards now.
            decoration: isPast ? TextDecoration.lineThrough : null, 
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy').format(med.scheduleDateTime),
              style: TextStyle(fontSize: 12, color: isPast ? Colors.grey.shade500 : Colors.black54),
            ),
            Text(
              DateFormat('hh:mm a').format(med.scheduleDateTime),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPast ? Colors.grey.shade500 : _accentColor,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
          onSelected: (value) {
            if (value == 'edit' && !isPast) _editMedicine(med);
            if (value == 'delete') _deleteMedicine(med);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit', 
              enabled: !isPast, 
              child: Row(
                children: [
                  Icon(Icons.edit, color: !isPast ? _primaryAppColor : Colors.grey), 
                  const SizedBox(width: 8), 
                  Text("Edit Reminder", style: TextStyle(color: !isPast ? Colors.black87 : Colors.grey)),
                ]
              )
            ),
            const PopupMenuItem(
              value: 'delete', 
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red), 
                  SizedBox(width: 8), 
                  Text("Delete Reminder", style: TextStyle(color: Colors.red)),
                ]
              )
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Log Out"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: _primaryAppColor))),
            ElevatedButton(
              onPressed: _logout, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Log Out", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _logout() async {
    if (mounted) Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      // Assuming LoginPage is correctly imported
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );
    }
  }

  // Custom widget for the icon with badge
  Widget _buildHistoryIconWithBadge() {
    return Stack(
      children: [
        IconButton(
          // The history button is correctly set up to navigate
          icon: const Icon(Icons.history, color: Colors.white),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MedicineHistoryPage(userId: widget.user.id!))),
          tooltip: "Medicine History", // Updated tooltip for clarity
        ),
        if (_pendingCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primaryAppColor, width: 1.5), // Subtle border for contrast
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$_pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text("Hello, ${widget.user.name.split(' ').first} 👋", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        // --- USES _primaryAppColor (now Teal.shade600) ---
        backgroundColor: _primaryAppColor, 
        // ------------------------------------------------
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // ⭐ ADDED: Red Reminder Icon 
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.redAccent), // A prominent red icon
            onPressed: () {
              // Optional: Add logic to show a list of pending reminders or a specific alert
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Showing active reminders!"),
                duration: Duration(seconds: 1),
              ));
            },
            tooltip: "Active Reminders",
          ),
          
          // Use the custom widget with the badge for History
          _buildHistoryIconWithBadge(),
          
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user))),
            tooltip: "Profile",
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _showLogoutDialog, tooltip: "Logout"),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMedicines,
        color: _primaryAppColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add Reminder Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Set a New Reminder", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryAppColor)),
                        const SizedBox(height: 15),
                        // Text Fields with slight visual enhancement
                        TextField(
                          controller: _nameController, 
                          decoration: InputDecoration(
                            labelText: "Medicine Name *",
                            prefixIcon: Icon(Icons.healing, color: _accentColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _descController, 
                          decoration: InputDecoration(
                            labelText: "Description (optional)",
                            prefixIcon: Icon(Icons.notes, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Date/Time Picker Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _primaryAppColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_filled, color: _primaryAppColor),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      DateFormat('MMM d, yyyy - hh:mm a').format(_selectedDateTime),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                  )),
                              TextButton(
                                onPressed: _pickDateTime, 
                                child: Text("CHANGE", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryAppColor))),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Add Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_alarm, color: Colors.white),
                            label: const Text("Add Reminder", style: TextStyle(fontSize: 16, color: Colors.white)),
                            onPressed: _addMedicine,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryAppColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Upcoming Medicines Section
                Text("Upcoming Reminders", 
                  style: TextStyle(
                    fontWeight: FontWeight.w800, 
                    fontSize: 20, 
                    color: Colors.black87
                  )
                ),
                const Divider(height: 15, thickness: 2),

                _upcomingMedicines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.alarm_off, size: 50, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text("You're all set! No upcoming medicine reminders.", 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    // Use _upcomingMedicines list here
                    : Column(children: _upcomingMedicines.map((med) => _buildMedicineCard(med)).toList()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}