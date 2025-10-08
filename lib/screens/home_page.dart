import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
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
  final MaterialColor _primarySwatch = Colors.teal;
  final MaterialColor _accentSwatch = Colors.indigo;
  final Color _primaryAppColor = Colors.teal.shade600;
  final Color _accentColor = Colors.indigo.shade400;

  final _db = DBHelper();
  List<Medicine> _medicines = [];
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  // Set a default time 5 minutes in the future for convenience
  DateTime _selectedDateTime = DateTime.now().add(Duration(minutes: 5)); 

  @override
  void initState() {
    super.initState();
    NotificationService().initNotification(); 
    _loadMedicines();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _loadMedicines() async {
    // 1. Fetch medicines specific to the current user
    _medicines = await _db.getUserMedicines(widget.user.id!);
    // 2. Sort them by date and time
    _medicines.sort((a, b) => a.scheduleDateTime.compareTo(b.scheduleDateTime));
    setState(() {});
  }

  void _pickDateTime() async {
    DateTime now = DateTime.now();

    // Date Picker
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isAfter(now) ? _selectedDateTime : now.add(Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryAppColor, 
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    // Time Picker
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
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _addMedicine() async {
    String name = _nameController.text.trim();
    // Use a slight offset to ensure selection isn't literally seconds ago
    DateTime now = DateTime.now().subtract(Duration(seconds: 1)); 

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Medicine Name is required."),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    } 
    
    if (_selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Please select a future date and time for the reminder."),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    Medicine med = Medicine(
      userId: widget.user.id!,
      name: name,
      description: _descController.text.trim(),
      scheduleDateTime: _selectedDateTime,
    );

    // Save to database and get the ID
    med.id = await _db.insertMedicine(med);

    // Schedule the notification using the returned ID
    await NotificationService().scheduleNotification(
      med.id!,
      "Medicine Reminder",
      "Time to take ${med.name} - ${med.description}",
      med.scheduleDateTime,
    );

    // Text-to-speech feedback
    FlutterTts tts = FlutterTts();
    await tts.speak(
        "Medicine ${med.name} reminder scheduled at ${DateFormat('hh:mm a').format(med.scheduleDateTime)}");

    _showSuccessDialog(med);
    
    // Clear form and reset date/time
    _nameController.clear();
    _descController.clear();
    setState(() {
      _selectedDateTime = DateTime.now().add(Duration(minutes: 5)); 
    });
    
    _loadMedicines();
  }

  void _showSuccessDialog(Medicine med) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text("Reminder Set!", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  "Medicine: ${med.name}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  "Time: ${DateFormat('MMM d, yyyy \n(hh:mm a)').format(med.scheduleDateTime)}",
                  style: TextStyle(color: _accentColor, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (med.description.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text("Details: ${med.description}", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
                ],
                SizedBox(height: 15),
                Text("A notification will be triggered at the scheduled time.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("OK", style: TextStyle(color: _primaryAppColor, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteMedicine(Medicine med) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text("Confirm Deletion"),
            ],
          ),
          content: Text("Are you sure you want to delete the reminder for \"${med.name}\"? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), 
              child: Text("Cancel", style: TextStyle(color: _primaryAppColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _db.deleteMedicine(med.id!);
      NotificationService().cancelNotification(med.id!);
      _loadMedicines(); 

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Medicine \"${med.name}\" reminder deleted!"),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _editMedicine(Medicine med) async {
    final _editNameController = TextEditingController(text: med.name);
    final _editDescController = TextEditingController(text: med.description);
    DateTime _tempEditDateTime = med.scheduleDateTime; 

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text("Edit Medicine Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: _editNameController,
                      decoration: InputDecoration(
                          labelText: "Medicine Name",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medication_outlined, color: _accentColor))),
                  SizedBox(height: 10),
                  TextField(
                      controller: _editDescController,
                      decoration: InputDecoration(
                          labelText: "Description", border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description_outlined, color: _accentColor))),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Text(DateFormat('MMM d, yyyy - hh:mm a')
                            .format(_tempEditDateTime)), 
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: () async {
                          // Date picker logic
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _tempEditDateTime.isBefore(DateTime.now()) ? DateTime.now() : _tempEditDateTime,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                            builder: (context, child) => Theme(
                                data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _primaryAppColor)), child: child!),
                          );
                          if (pickedDate == null) return;

                          // Time picker logic
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_tempEditDateTime),
                            builder: (context, child) => Theme(
                                data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: _primaryAppColor)), child: child!),
                          );
                          if (pickedTime == null) return;

                          setDialogState(() { 
                            _tempEditDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        },
                        child: Text("Change Time"),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    if (_editNameController.text.trim().isEmpty || _tempEditDateTime.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Name is required and time must be in the future."),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }
                    
                    // Update model and DB
                    med.name = _editNameController.text.trim();
                    med.description = _editDescController.text.trim();
                    med.scheduleDateTime = _tempEditDateTime;
                    await _db.updateMedicine(med);

                    // Cancel old notification and schedule a new one
                    NotificationService().cancelNotification(med.id!);
                    await NotificationService().scheduleNotification(
                      med.id!,
                      "Medicine Reminder",
                      "Time to take ${med.name}",
                      med.scheduleDateTime,
                    );

                    _loadMedicines();
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Medicine \"${med.name}\" updated successfully!"),
                      backgroundColor: Colors.blue,
                    ));
                  },
                  child: Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMedicineCard(Medicine med) {
    bool isPast = med.scheduleDateTime.isBefore(DateTime.now());
    
    // Conditional styling based on whether the reminder is past or future
    Color primaryCardColor = isPast ? Colors.grey.shade400 : _primaryAppColor;
    Color secondaryCardColor = isPast ? Colors.grey.shade600 : _primarySwatch.shade400; 

    Color backgroundColor = isPast ? Colors.white70 : Colors.white;

    IconData icon = isPast ? Icons.done_all : Icons.alarm_on;
    TextStyle titleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: isPast ? Colors.grey.shade800 : _primaryAppColor, 
      decoration: isPast ? TextDecoration.lineThrough : TextDecoration.none,
    );
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isPast ? 0.05 : 0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryCardColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: primaryCardColor, width: 2),
          ),
          child: Icon(icon, color: primaryCardColor, size: 28),
        ),
        title: Text(med.name, style: titleStyle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              DateFormat('E, MMM d').format(med.scheduleDateTime), 
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: secondaryCardColor),
            ),
            Text(
              DateFormat('hh:mm a').format(med.scheduleDateTime), 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primaryCardColor),
            ),
            if (med.description.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(
                med.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            if (isPast) 
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text("Completed / Expired", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.black54),
          onSelected: (String result) {
            if (result == 'edit') {
              if (!isPast) _editMedicine(med);
            } else if (result == 'delete') {
              _deleteMedicine(med);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'edit',
              enabled: !isPast, 
              child: Row(
                children: [
                  Icon(Icons.edit, color: isPast ? Colors.grey : Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit Reminder'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Reminder'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.exit_to_app, color: _accentColor, size: 28),
              SizedBox(width: 8),
              Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text("Are you sure you want to log out of the application? Your session will be ended."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Dismiss dialog
              child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: _logout, // Call the logout function
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Clears user session and navigates to the LoginPage with a custom Fade and Scale transition.
  void _logout() async {
    // 1. Close the dialog
    Navigator.of(context).pop(); 

    // 2. Clear user session/state
    final prefs = await SharedPreferences.getInstance();
    // Clear all stored data (UserID, token, etc.) to log out the user.
    await prefs.clear(); 
    
    // 3. Define the custom animated route for the Login Page transition (No rotation)
    final newRoute = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => 
          LoginPage(), // Use your actual LoginPage widget here
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        
        // Scale Tween (Starts small, expands to full size)
        var scaleTween = Tween<double>(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)); 
        
        // Fade Tween (Starts transparent, fades in)
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut));

        return FadeTransition(
          opacity: fadeTween.animate(animation), 
          child: ScaleTransition(
            scale: scaleTween.animate(animation), 
            // Removed RotationTransition
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 700), // Custom duration
    );

    // 4. Push the new route and remove all previous routes
    // This is vital to prevent the user from navigating back to the home screen
    Navigator.of(context).pushAndRemoveUntil(
      newRoute,
      (Route<dynamic> route) => false, // Removes all previous routes
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, 
      appBar: AppBar(
        title: Text(
          "Hello, ${widget.user.name.split(' ').first} 👋", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
        ),
        backgroundColor: _primaryAppColor,
        elevation: 0, 
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          // HISTORY BUTTON
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicineHistoryPage(userId: widget.user.id!),
                ),
              );
            },
            tooltip: 'View History',
          ),
          // PROFILE BUTTON
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user)),
              );
            },
            tooltip: 'View Profile',
          ),
          // LOGOUT BUTTON
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog, // Calls the confirmation dialog
            tooltip: 'Log Out',
          ),
        ],
        toolbarHeight: 80, 
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SCHEDULE NEW REMINDER CARD
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                margin: EdgeInsets.only(top: 0),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Set a New Reminder 💊", 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryAppColor)),
                      SizedBox(height: 15),
                      // Medicine Name Input
                      TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Medicine Name (Required)",
                            hintText: "e.g., Vitamin D, Insulin",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.medication_outlined, color: _accentColor),
                            floatingLabelStyle: TextStyle(color: _accentColor)
                          )),
                      SizedBox(height: 12),
                      // Description Input
                      TextField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: "Dosage/Details (Optional)",
                            hintText: "e.g., 1 pill after dinner",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.description_outlined, color: _accentColor),
                            floatingLabelStyle: TextStyle(color: _accentColor)
                          )),
                      SizedBox(height: 15),
                      // Date/Time Picker Row
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, color: _accentColor, size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              DateFormat('MMM d, yyyy \n hh:mm a').format(_selectedDateTime), 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)
                            ),
                          ),
                          ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10)
                                ),
                              onPressed: _pickDateTime,
                              icon: Icon(Icons.calendar_today, size: 18),
                              label: Text("Change", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Schedule Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 55),
                            backgroundColor: _primaryAppColor,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: _addMedicine,
                        child: Text("Schedule Reminder", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),

              // UPCOMING REMINDERS LIST Header
              Text(
                "Upcoming Doses 🗓️", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87)
              ),
              SizedBox(height: 15),

              // Conditional List View (or Empty State)
              _medicines.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50.0),
                        child: Column(
                          children: [
                            Icon(Icons.medication_liquid_outlined, size: 80, color: Colors.grey.shade300),
                            SizedBox(height: 15),
                            Text(
                              "All clear! Add your first medicine reminder above.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true, 
                      physics: NeverScrollableScrollPhysics(), 
                      itemCount: _medicines.length,
                      itemBuilder: (_, index) {
                        final med = _medicines[index];
                        return _buildMedicineCard(med);
                      },
                    ),
              SizedBox(height: 30), 
            ],
          ),
        ),
      ),
    );
  }
}