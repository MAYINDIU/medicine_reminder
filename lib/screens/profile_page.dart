import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/db_helper.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _db = DBHelper();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  
  // Controllers for the new password dialog
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();

  final Color _primaryAppColor = Colors.teal.shade600;
  final Color _accentColor = Colors.indigo.shade400;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name ?? "");
    _emailController = TextEditingController(text: widget.user.email ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  void _updateProfile() async {
    // Validation and update logic remains the same (provided in the prompt)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_nameController.text == widget.user.name &&
        _emailController.text == widget.user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No changes detected.", style: TextStyle(color: Colors.black87)),
          backgroundColor: Colors.yellow.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 15),
            Text("Updating profile...", style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: _accentColor,
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    widget.user.name = _nameController.text.trim();
    widget.user.email = _emailController.text.trim();
    widget.user.updatedAt = DateTime.now();

    int result = await _db.updateUser(widget.user);
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result > 0) {
      setState(() {}); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile updated successfully! 🎉"),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile update failed. Please try again."),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ######################################################################
  // ✅ NEW METHOD: Show Change Password Dialog
  // ######################################################################
  void _showChangePasswordDialog() {
    // Clear controllers before showing the dialog
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmNewPasswordController.clear();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Change Password", style: TextStyle(color: _primaryAppColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: _passwordFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Current Password
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Current Password",
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  // New Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "New Password",
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Confirm New Password
                  TextFormField(
                    controller: _confirmNewPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm New Password",
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("CANCEL", style: TextStyle(color: Colors.grey.shade600)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryAppColor, foregroundColor: Colors.white),
              child: const Text("CHANGE"),
              onPressed: () {
                // Perform password change action
                if (_passwordFormKey.currentState!.validate()) {
                  _handlePasswordChange();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ######################################################################
  // ✅ NEW METHOD: Handle Password Change Logic
  // ######################################################################
  void _handlePasswordChange() async {
    Navigator.of(context).pop(); // Close the dialog first

    String currentPass = _currentPasswordController.text;
    String newPass = _newPasswordController.text;

    // 1. Verify Current Password
    if (currentPass != widget.user.password) { // NOTE: This assumes password is NOT hashed. If it is, you need to check the hash here.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: Current password is incorrect."),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    
    // 2. Perform Update
    widget.user.password = newPass; 
    widget.user.updatedAt = DateTime.now();

    int result = await _db.updateUser(widget.user);
    
    if (result > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Password changed successfully!"),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Password change failed due to a database error."),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: TextStyle(
            color: _primaryAppColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: _primaryAppColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header/Avatar Section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: _accentColor.withOpacity(0.15),
                      child: Icon(
                        Icons.person_outline,
                        size: 60,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _nameController.text.isEmpty ? "User Profile" : _nameController.text,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _primaryAppColor,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),

              // Name Field
              TextFormField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                decoration: InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.person_outline, color: _accentColor),
                  floatingLabelStyle: TextStyle(color: _primaryAppColor, fontWeight: FontWeight.bold),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email_outlined, color: _accentColor),
                  floatingLabelStyle: TextStyle(color: _primaryAppColor, fontWeight: FontWeight.bold),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Update Button
              ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 55),
                  backgroundColor: _primaryAppColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "SAVE CHANGES",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Password Change Button (Now opens a dialog)
              TextButton(
                 onPressed: _showChangePasswordDialog, // ⬅️ Call the new dialog method
                 child: Text("Change Password", style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
      ),
    );
  }
}