import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:central_central_new/app_header.dart';
import 'package:central_central_new/home_page.dart';
import 'package:central_central_new/profile_page.dart';
import 'package:central_central_new/manage_users_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:central_central_new/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _adminMode = false;
  String _studentName = "User";
  int _selectedIndex = 2;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _adminMode = prefs.getBool('adminMode') ?? false;
      _studentName =
          user?.displayName ?? user?.email?.split('@').first ?? "User";
    });
  }

  Future<void> _toggleAdminMode(bool value) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('adminMode', value);
      setState(() {
        _adminMode = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin mode ${value ? 'enabled' : 'disabled'}')),
      );
    } catch (e) {
      String errorMessage = 'Error updating admin mode';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _toggleAdminMode(value),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user is signed in or email is unavailable'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      String errorMessage = 'Error sending password reset email';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _resetPassword),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            "Logout",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to log out?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _handleLogout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      String errorMessage = 'Error logging out';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _handleLogout),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HomePage(studentName: _studentName)),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else if (index == 2) {
      // Already on SettingsPage
    }
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = index == _selectedIndex;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: isSelected
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            )
          : null,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: "Settings",
        studentName: _studentName,
        onLogoutPressed: _showLogoutConfirmationDialog,
      ),
      drawer: AppDrawer(studentName: _studentName),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text(
                          'Admin Mode',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: _adminMode,
                        onChanged: _toggleAdminMode,
                        activeColor: const Color(0xFF2A68CC),
                      ),
                      if (_adminMode)
                        ListTile(
                          leading: const Icon(
                            Icons.group,
                            color: Colors.white70,
                          ),
                          title: const Text(
                            'Manage Users',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageUsersPage(),
                              ),
                            );
                          },
                        ),
                      ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Manage Profile',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfilePage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock, color: Colors.white70),
                        title: const Text(
                          'Change Password',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: _resetPassword,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF732525)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Stack(
        children: [
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF732525),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
              border: Border(
                top: BorderSide(color: Color(0xFFB8B292), width: 4.0),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              items: [
                BottomNavigationBarItem(
                  icon: _buildNavItem(Icons.home, 0),
                  label: "Home",
                ),
                BottomNavigationBarItem(
                  icon: _buildNavItem(Icons.person, 1),
                  label: "Profile",
                ),
                BottomNavigationBarItem(
                  icon: _buildNavItem(Icons.settings, 2),
                  label: "Settings",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
