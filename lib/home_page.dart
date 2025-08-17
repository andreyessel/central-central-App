import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:central_central_new/login_page.dart';
import 'package:central_central_new/notes_page.dart';
import 'package:central_central_new/campus_services_page.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:central_central_new/notifications_page.dart';
import 'package:central_central_new/attendance_page.dart';
import 'package:central_central_new/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:central_central_new/ask_central_page.dart';
import 'package:central_central_new/school_websites_page.dart';
import 'package:central_central_new/todo_page.dart';
import 'package:central_central_new/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HomePage extends StatefulWidget {
  final String studentName;
  const HomePage({super.key, required this.studentName});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  int _unreadNotificationsCount = 0;

  final PageController _countdownController = PageController();
  late Timer _countdownSwitchTimer;
  late Timer _countdownTickTimer;

  final PageController _eventController = PageController();
  late Timer _eventAutoScrollTimer;

  DateTime? _nearestExamDate;
  DateTime? _nearestEventDate;
  List<Map<String, dynamic>> _events = [];
  StreamSubscription<QuerySnapshot>? _todosSubscription;
  StreamSubscription<QuerySnapshot>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _loadAdminStatus();
    _loadNearestDates();
    _loadUnreadNotifications();
    _loadEvents();
    _startTimers();
  }

  @override
  void dispose() {
    _countdownSwitchTimer.cancel();
    _countdownTickTimer.cancel();
    _countdownController.dispose();
    _eventAutoScrollTimer.cancel();
    _eventController.dispose();
    _todosSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      setState(() {
        _unreadNotificationsCount = snapshot.docs.length;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading notifications: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadUnreadNotifications,
          ),
        ),
      );
    }
  }

  void _startTimers() {
    _countdownSwitchTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_countdownController.hasClients) {
        final int nextPage = (_countdownController.page?.round() ?? 0) + 1;
        _countdownController.animateToPage(
          nextPage % 2,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    _countdownTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    _startEventAutoScrollTimer();
  }

  void _startEventAutoScrollTimer() {
    _eventAutoScrollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_eventController.hasClients && _events.isNotEmpty) {
        final int nextPage = (_eventController.page?.round() ?? 0) + 1;
        _eventController.animateToPage(
          nextPage % _events.length,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('adminMode') ?? false;
    });
  }

  void _loadEvents() {
    _eventsSubscription?.cancel();
    _eventsSubscription = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .listen(
          (snapshot) {
            setState(() {
              _events = snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'title': data['title'] ?? '',
                  'imageUrl': data['imageUrl'],
                  'createdBy': data['createdBy'] ?? '',
                };
              }).toList();
            });
          },
          onError: (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error loading events: $e')));
          },
        );
  }

  void _loadNearestDates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _todosSubscription?.cancel();
    _todosSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) async {
            DateTime? nearestExam;
            DateTime? nearestEvent;
            final now = DateTime.now();

            for (var doc in snapshot.docs) {
              final data = doc.data();
              if (data['dueDate'] != null && data['taskType'] != null) {
                final dueDate = DateTime.parse(data['dueDate']);
                if (dueDate.isAfter(now)) {
                  if (data['taskType'] == 'Exam' &&
                      (nearestExam == null || dueDate.isBefore(nearestExam))) {
                    nearestExam = dueDate;
                  } else if (data['taskType'] == 'Event' &&
                      (nearestEvent == null ||
                          dueDate.isBefore(nearestEvent))) {
                    nearestEvent = dueDate;
                  }
                }
              }
            }

            setState(() {
              _nearestExamDate = nearestExam;
              _nearestEventDate = nearestEvent;
            });

            final prefs = await SharedPreferences.getInstance();
            if (nearestExam != null) {
              await prefs.setString(
                'examCountdownDate',
                nearestExam.toIso8601String(),
              );
            } else {
              await prefs.remove('examCountdownDate');
            }
            if (nearestEvent != null) {
              await prefs.setString(
                'eventCountdownDate',
                nearestEvent.toIso8601String(),
              );
            } else {
              await prefs.remove('eventCountdownDate');
            }
          },
          onError: (e) async {
            final prefs = await SharedPreferences.getInstance();
            final examDate = prefs.getString('examCountdownDate');
            final eventDate = prefs.getString('eventCountdownDate');

            setState(() {
              _nearestExamDate = examDate != null
                  ? DateTime.parse(examDate)
                  : null;
              _nearestEventDate = eventDate != null
                  ? DateTime.parse(eventDate)
                  : null;
            });
          },
        );
  }

  void _showAddEditEventDialog({Map<String, dynamic>? event}) {
    final isEdit = event != null;
    final titleController = TextEditingController(text: event?['title'] ?? '');
    final imageUrlController = TextEditingController(
      text: event?['imageUrl'] ?? '',
    );

    Future<void> _pickImage() async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null && context.mounted) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final storageRef = FirebaseStorage.instance
              .ref()
              .child('event_images')
              .child(
                '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
          await storageRef.putFile(File(pickedFile.path));
          final downloadUrl = await storageRef.getDownloadURL();
          imageUrlController.text = downloadUrl;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: Text(
            isEdit ? 'Edit Event' : 'Add Event',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2A68CC)),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: imageUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF2A68CC)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo, color: Colors.white70),
                    onPressed: _pickImage,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                final data = {
                  'title': titleController.text.trim(),
                  'imageUrl': imageUrlController.text.trim().isEmpty
                      ? null
                      : imageUrlController.text.trim(),
                  'createdBy': user.uid,
                };

                try {
                  if (isEdit) {
                    await FirebaseFirestore.instance
                        .collection('events')
                        .doc(event['id'])
                        .set(data);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('events')
                        .add(data);
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving event: $e')),
                  );
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Color(0xFF2A68CC)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteEventDialog(String eventId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Delete Event',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete this event?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('events')
                      .doc(eventId)
                      .delete();
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting event: $e')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCountdownTimer(bool isExam) {
    final targetDate = isExam ? _nearestExamDate : _nearestEventDate;
    final taskType = isExam ? 'Exam' : 'Event';
    return GestureDetector(
      onTap: () {
        if (targetDate != null && targetDate.isAfter(DateTime.now())) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ToDoPage(initialDate: targetDate, initialTaskType: taskType),
            ),
          ).then((_) => _loadNearestDates());
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1D283C),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: targetDate == null
              ? Text(
                  isExam ? "No exam scheduled" : "No event scheduled",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                )
              : targetDate.isBefore(DateTime.now())
              ? Text(
                  isExam ? "Exam completed" : "Event completed",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      isExam ? "Next Exam" : "Next Event",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    _buildTimeBox(
                      "Days",
                      targetDate.difference(DateTime.now()).inDays,
                    ),
                    _buildTimeBox(
                      "Hour",
                      targetDate.difference(DateTime.now()).inHours % 24,
                    ),
                    _buildTimeBox(
                      "Min",
                      targetDate.difference(DateTime.now()).inMinutes % 60,
                    ),
                    _buildTimeBox(
                      "Sec",
                      targetDate.difference(DateTime.now()).inSeconds % 60,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTimeBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2A68CC),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 8)),
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // Home - already here, no action needed
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      ).then((_) => _loadNearestDates());
    } else if (index == 2) {
      await _loadAdminStatus();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      ).then((_) => _loadNearestDates());
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

  Widget _featureTile(
    String title,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 17, 17, 17),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF732525),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            border: Border(
              bottom: BorderSide(color: Color(0xFFB8B292), width: 4.0),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/central_central_logo.png',
                          height: 40,
                          width: 40,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Welcome Back\n${widget.studentName}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                ).then((_) => _loadUnreadNotifications());
                              },
                            ),
                            if (_unreadNotificationsCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$_unreadNotificationsCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: _showLogoutConfirmationDialog,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 60,
                  child: PageView.builder(
                    controller: _countdownController,
                    itemCount: 2,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (_, index) {
                      return index == 0
                          ? _buildCountdownTimer(true)
                          : _buildCountdownTimer(false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: AppDrawer(studentName: widget.studentName),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _eventController,
                    itemCount: _events.isEmpty ? 1 : _events.length,
                    itemBuilder: (_, index) {
                      if (_events.isEmpty) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFC0C0C0),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'No events available',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }
                      final event = _events[index];
                      return GestureDetector(
                        onTap: _isAdmin
                            ? () => _showAddEditEventDialog(event: event)
                            : null,
                        child: Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFC0C0C0),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child:
                                    event['imageUrl'] != null &&
                                        event['imageUrl'].isNotEmpty
                                    ? Image.network(
                                        event['imageUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Text(
                                                  event['title'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                      )
                                    : Text(
                                        event['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (_events.isNotEmpty) {
                              final int currentPage =
                                  _eventController.page?.round() ?? 0;
                              final int previousPage =
                                  (currentPage - 1 + _events.length) %
                                  _events.length;
                              _eventController.animateToPage(
                                previousPage,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (_events.isNotEmpty) {
                              final int currentPage =
                                  _eventController.page?.round() ?? 0;
                              final int nextPage =
                                  (currentPage + 1) % _events.length;
                              _eventController.animateToPage(
                                nextPage,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: Colors.black.withOpacity(0.5),
                    onOpened: () {
                      _eventAutoScrollTimer.cancel();
                    },
                    onCanceled: _startEventAutoScrollTimer,
                    onSelected: (value) {
                      if (value == 'add') {
                        _showAddEditEventDialog();
                      } else if (value == 'delete' && _events.isNotEmpty) {
                        _showDeleteEventDialog(
                          _events[_eventController.page?.round() ?? 0]['id'],
                        );
                      }
                      _startEventAutoScrollTimer();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: Material(
                                color: const Color(0xFF732525),
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).pop('add'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: Material(
                                color: const Color(0xFF732525),
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                  onPressed: _events.isNotEmpty
                                      ? () =>
                                            Navigator.of(context).pop('delete')
                                      : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Academic',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(10),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _featureTile(
                          "Notes Organizer",
                          Icons.note,
                          Colors.green,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NotesPage(studentName: widget.studentName),
                              ),
                            ).then((_) => _loadNearestDates());
                          },
                        ),
                        _featureTile(
                          "Sign Attendance",
                          Icons.qr_code_scanner,
                          Colors.deepPurple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AttendancePage(
                                  studentName: widget.studentName,
                                  isAdmin: _isAdmin,
                                ),
                                settings: const RouteSettings(
                                  name: '/attendance',
                                ),
                              ),
                            ).then((_) => _loadNearestDates());
                          },
                        ),
                        _featureTile(
                          "School Websites",
                          Icons.language,
                          const Color(0xFF8E1919),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SchoolWebsitesPage(),
                              ),
                            ).then((_) => _loadNearestDates());
                          },
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Personal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(10),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _featureTile(
                          "To-Do List",
                          Icons.checklist,
                          Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ToDoPage()),
                          ).then((_) => _loadNearestDates()),
                        ),
                        _featureTile(
                          "Campus Services",
                          Icons.fastfood,
                          Colors.pink,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CampusServicesPage(),
                              ),
                            ).then((_) => _loadNearestDates());
                          },
                        ),
                        _featureTile(
                          "Ask Central",
                          Icons.help,
                          const Color(0xFF339C8F),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AskCentralPage(),
                              ),
                            ).then((_) => _loadNearestDates());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D283C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFF292929),
        child: Center(
          child: Text(
            'Content for $title',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
    );
  }
}
