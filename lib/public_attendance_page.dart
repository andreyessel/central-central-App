import 'package:central_central_new/login_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:central_central_new/app_header.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceEntry {
  final String id;
  final String userId;
  final String studentName;
  final String studentIndexNumber;
  final DateTime timestamp;

  AttendanceEntry({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.studentIndexNumber,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'studentName': studentName,
      'studentIndexNumber': studentIndexNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AttendanceEntry.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceEntry(
      id: id,
      userId: map['userId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentIndexNumber: map['studentIndexNumber'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class PublicAttendancePage extends StatefulWidget {
  final String qrCodeId;

  const PublicAttendancePage({super.key, required this.qrCodeId});

  @override
  State<PublicAttendancePage> createState() => _PublicAttendancePageState();
}

class _PublicAttendancePageState extends State<PublicAttendancePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _indexController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _studentName = "User";
  bool _isLoading = false;
  bool _isEditing = false;
  AttendanceEntry? _userEntry;
  List<AttendanceEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadStudentName();
    _loadEntries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _indexController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _studentName =
            user.displayName ?? user.email?.split('@').first ?? "User";
      });
      _nameController.text = _studentName;
    }
    final prefs = await SharedPreferences.getInstance();
    _indexController.text = prefs.getString('studentNumber') ?? '';
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('qr_attendance')
          .doc(widget.qrCodeId)
          .collection('entries')
          .get();

      setState(() {
        _entries = snapshot.docs
            .map((doc) => AttendanceEntry.fromMap(doc.data(), doc.id))
            .toList();
        _userEntry = _entries.firstWhere(
          (entry) => entry.userId == user.uid,
          // ignore: cast_from_null_always_fails
          orElse: () => null as AttendanceEntry,
        );
        if (_userEntry != null) {
          _nameController.text = _userEntry!.studentName;
          _indexController.text = _userEntry!.studentIndexNumber;
        }
      });
    } catch (e) {
      String errorMessage = 'Error loading attendance entries';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _loadEntries),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty ||
        _indexController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final entry = AttendanceEntry(
        id: _userEntry?.id ?? '',
        userId: user.uid,
        studentName: _nameController.text.trim(),
        studentIndexNumber: _indexController.text.trim(),
        timestamp: _userEntry?.timestamp ?? DateTime.now(),
      );

      if (_userEntry == null) {
        // Create new entry
        final docRef = await _firestore
            .collection('qr_attendance')
            .doc(widget.qrCodeId)
            .collection('entries')
            .add(entry.toMap());
        setState(() {
          _userEntry = AttendanceEntry(
            id: docRef.id,
            userId: entry.userId,
            studentName: entry.studentName,
            studentIndexNumber: entry.studentIndexNumber,
            timestamp: entry.timestamp,
          );
        });
      } else {
        // Update existing entry
        await _firestore
            .collection('qr_attendance')
            .doc(widget.qrCodeId)
            .collection('entries')
            .doc(_userEntry!.id)
            .update({
              'studentName': entry.studentName,
              'studentIndexNumber': entry.studentIndexNumber,
            });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('studentNumber', _indexController.text.trim());

      await _loadEntries();
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry saved successfully')));
    } catch (e) {
      String errorMessage = 'Error saving entry';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _saveEntry),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Color(0xFF2A68CC), width: 2.0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 17, 17, 17),
      appBar: AppHeader(
        title: "Attendance Record",
        studentName: _studentName,
        onLogoutPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF333333),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                "Are you sure you want to log out?",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await FirebaseAuth.instance.signOut();
                    await GoogleSignIn().signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      drawer: AppDrawer(studentName: _studentName),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF732525)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Attendance Entry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildEditableField(
                    label: 'Student Name',
                    controller: _nameController,
                    enabled: _isEditing || _userEntry == null,
                  ),
                  _buildEditableField(
                    label: 'Student Index Number',
                    controller: _indexController,
                    enabled: _isEditing || _userEntry == null,
                    keyboardType: TextInputType.number,
                  ),
                  if (_userEntry != null)
                    _buildEditableField(
                      label: 'Scan Time',
                      controller: TextEditingController(
                        text: DateFormat(
                          'MMM dd, yyyy – hh:mm a',
                        ).format(_userEntry!.timestamp),
                      ),
                      enabled: false,
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _isEditing || _userEntry == null
                            ? _saveEntry
                            : () => setState(() => _isEditing = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A68CC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Text(
                          _isEditing || _userEntry == null ? 'Save' : 'Edit',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (_isEditing)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _nameController.text = _userEntry!.studentName;
                              _indexController.text =
                                  _userEntry!.studentIndexNumber;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All Attendance Entries',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _entries.isEmpty
                      ? const Center(
                          child: Text(
                            'No attendance entries yet.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final isUserEntry =
                                entry.userId ==
                                FirebaseAuth.instance.currentUser?.uid;
                            return Card(
                              color: isUserEntry
                                  ? const Color(0xFF2A68CC).withOpacity(0.2)
                                  : Colors.black.withOpacity(0.3),
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(
                                  entry.studentName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Index: ${entry.studentIndexNumber}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      'Scanned: ${DateFormat('MMM dd, yyyy – hh:mm a').format(entry.timestamp)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isUserEntry
                                    ? const Icon(
                                        Icons.edit,
                                        color: Colors.white70,
                                      )
                                    : null,
                                onTap: isUserEntry
                                    ? () => setState(() => _isEditing = true)
                                    : null,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
