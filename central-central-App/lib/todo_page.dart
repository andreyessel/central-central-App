import 'package:central_central_new/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:central_central_new/login_page.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:central_central_new/app_header.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';

class ToDoPage extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialTaskType;

  const ToDoPage({Key? key, this.initialDate, this.initialTaskType})
    : super(key: key);

  @override
  State<ToDoPage> createState() => _ToDoPageState();
}

class _ToDoPageState extends State<ToDoPage> with TickerProviderStateMixin {
  final List<ToDoItem> _todos = [];
  final TextEditingController _todoController = TextEditingController();
  String _studentName = "User";
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String? _selectedTaskType;
  final ScrollController _scrollController = ScrollController();
  final Map<DateTime, List<Color>> _dateColors = {};
  final Map<DateTime, List<ToDoItem>> _tasksByDate = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _highlightController;
  bool _isLoading = false;
  bool _isAddingCustomCategory = false;
  final TextEditingController _customCategoryController =
      TextEditingController();
  List<String> _availableCategories = ['General', 'Exam', 'Event'];

  // Add this helper to normalize dates (removes time part)
  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadStudentName();
    _loadTodos().then((_) {
      if (widget.initialDate != null) {
        setState(() {
          _selectedDay = _normalizeDate(widget.initialDate!);
          _focusedDay = _normalizeDate(widget.initialDate!);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToTask(_normalizeDate(widget.initialDate!));
        });
      }
      _scheduleTaskNotifications();
    });
    _loadSelectedDay();
  }

  @override
  void dispose() {
    _todoController.dispose();
    _scrollController.dispose();
    _highlightController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _studentName =
            user.displayName ?? user.email?.split('@').first ?? "User";
      });
    }
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .get();

      setState(() {
        _todos.clear();
        _dateColors.clear();
        _tasksByDate.clear();

        for (var doc in snapshot.docs) {
          final todo = ToDoItem.fromMap(doc.data(), doc.id);
          _todos.add(todo);

          if (todo.dueDate != null) {
            final date = _normalizeDate(todo.dueDate!);
            if (!_tasksByDate.containsKey(date)) {
              _tasksByDate[date] = [];
            }
            _tasksByDate[date]!.add(todo);

            if (!_dateColors.containsKey(date)) {
              _dateColors[date] = [];
            }
            _dateColors[date]!.add(todo.color);

            if (todo.taskType == 'Exam' || todo.taskType == 'Event') {
              _saveCountdownDate(todo.taskType!, todo.dueDate!);
            }
          }
        }
      });
    } catch (e) {
      String errorMessage = 'Error loading tasks';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _loadTodos),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleTaskNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      for (var todo in _todos) {
        if (todo.dueDate != null && !todo.isCompleted) {
          final now = DateTime.now();
          final timeUntilDue = todo.dueDate!.difference(now);

          // Notify when task is about to elapse (within 1 hour)
          if (timeUntilDue.inMinutes > 0 && timeUntilDue.inHours <= 1) {
            await _addNotification(
              title: 'Task Upcoming: ${todo.title}',
              body:
                  'Your task "${todo.title}" is due in ${timeUntilDue.inMinutes} minutes.',
              id: '${todo.id}_upcoming_${DateTime.now().millisecondsSinceEpoch}',
            );
          }

          // Notify when task has elapsed
          if (timeUntilDue.isNegative) {
            await _addNotification(
              title: 'Task Expired: ${todo.title}',
              body:
                  'Your task "${todo.title}" was due on ${DateFormat('MMM dd, yyyy – hh:mm a').format(todo.dueDate!)}.',
              id: '${todo.id}_elapsed_${DateTime.now().millisecondsSinceEpoch}',
            );
          }
        }
      }
    } catch (e) {
      String errorMessage = 'Error scheduling task notifications';
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
            onPressed: _scheduleTaskNotifications,
          ),
        ),
      );
    }
  }

  Future<void> _addNotification({
    required String title,
    required String body,
    required String id,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notification = NotificationItem(
        title: title,
        body: body,
        timestamp: DateTime.now(),
        id: '',
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(id)
          .set(notification.toMap());

      // Trigger push notification
      final fcmToken = (await _firestore
          .collection('users')
          .doc(user.uid)
          .get())['fcmToken'];
      if (fcmToken != null) {
        await FirebaseMessaging.instance.sendMessage(
          to: fcmToken,
          data: {'title': title, 'body': body},
        );
      }
    } catch (e) {
      String errorMessage = 'Error sending notification';
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
            onPressed: () => _addNotification(title: title, body: body, id: id),
          ),
        ),
      );
    }
  }

  Future<void> _saveTodo(ToDoItem todo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (todo.id == null) {
        final docRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('todos')
            .add(todo.toMap());
        todo = todo.copyWith(title: docRef.id);
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('todos')
            .doc(todo.id)
            .update(todo.toMap());
      }
      await _loadTodos();
      await _scheduleTaskNotifications();
    } catch (e) {
      String errorMessage = 'Error saving task';
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
            onPressed: () => _saveTodo(todo),
          ),
        ),
      );
    }
  }

  Future<void> _saveCountdownDate(String type, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${type.toLowerCase()}CountdownDate',
      date.toIso8601String(),
    );
  }

  Future<void> _deleteTodo(String? id) async {
    if (id == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(id)
          .delete();
      await _loadTodos();
      await _scheduleTaskNotifications();
    } catch (e) {
      String errorMessage = 'Error deleting task';
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
            onPressed: () => _deleteTodo(id),
          ),
        ),
      );
    }
  }

  Color _generateRandomColor() {
    return Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
  }

  Future<void> _addTodo() async {
    if (_todoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    if ((_selectedTaskType == 'Exam' || _selectedTaskType == 'Event') &&
        _selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date for exam/event tasks'),
        ),
      );
      return;
    }

    String? finalTaskType = _selectedTaskType;
    if (_isAddingCustomCategory && _customCategoryController.text.isNotEmpty) {
      finalTaskType = _customCategoryController.text;
      if (!_availableCategories.contains(finalTaskType)) {
        setState(() {
          _availableCategories.add(finalTaskType!);
        });
      }
    }

    final randomColor = _generateRandomColor();
    final newTodo = ToDoItem(
      title: _todoController.text,
      isCompleted: false,
      dueDate: _selectedDay,
      taskType: finalTaskType,
      color: randomColor,
    );

    await _saveTodo(newTodo);
    _todoController.clear();
    _customCategoryController.clear();
    setState(() {
      _selectedTaskType = null;
      _isAddingCustomCategory = false;
    });
  }

  void _scrollToTask(DateTime date) async {
    // Ensure tasks are loaded
    if (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_isLoading) return; // Exit if still loading
    }

    final normalizedDate = _normalizeDate(date);
    final tasks = _tasksByDate[normalizedDate] ?? [];
    if (tasks.isNotEmpty) {
      final filteredTasks = widget.initialTaskType != null
          ? tasks
                .where(
                  (task) =>
                      task.taskType?.toLowerCase() ==
                      widget.initialTaskType?.toLowerCase(),
                )
                .toList()
          : tasks;
      if (filteredTasks.isNotEmpty) {
        final index = _todos.indexWhere(
          (todo) => todo.id == filteredTasks.first.id,
        );
        if (index != -1) {
          _scrollController.animateTo(
            index * 100.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );

          setState(() {
            for (var todo in _todos) {
              todo.isHighlighted = false;
            }
            for (var task in filteredTasks) {
              task.isHighlighted = true;
            }
          });

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                for (var task in filteredTasks) {
                  task.isHighlighted = false;
                }
              });
            }
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No ${widget.initialTaskType} tasks found for ${DateFormat('MMM dd, yyyy').format(normalizedDate)}',
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No tasks found for ${DateFormat('MMM dd, yyyy').format(normalizedDate)}',
          ),
        ),
      );
    }
  }

  void _showTaskDialog(DateTime date) {
    final tasks = _tasksByDate[date] ?? [];
    if (tasks.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: Text(
            'Tasks for ${DateFormat('MMM dd, yyyy').format(date)}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tasks.length,
              itemBuilder: (ctx, index) {
                final task = tasks[index];
                return ListTile(
                  title: Text(
                    task.title,
                    style: TextStyle(
                      color: Colors.white,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: task.taskType != null
                      ? Text(
                          task.taskType!,
                          style: const TextStyle(color: Colors.white70),
                        )
                      : null,
                  leading: Checkbox(
                    value: task.isCompleted,
                    onChanged: (value) => _toggleTodo(task),
                    fillColor: MaterialStateProperty.resolveWith<Color>(
                      (states) => task.isCompleted
                          ? const Color(0xFF2A68CC)
                          : Colors.grey.shade700,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCalendarDay(DateTime day, DateTime focusedDay) {
    final colors = _dateColors[_normalizeDate(day)] ?? [];
    if (colors.isEmpty) {
      return Center(child: Text('${day.day}'));
    }

    if (colors.length == 1) {
      return Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.first),
        child: Center(
          child: Text(
            '${day.day}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } else {
      return Container(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(colors.length, (index) {
              final startAngle = index * (2 * pi / colors.length);
              return Positioned.fill(
                child: CustomPaint(
                  painter: _SlicePainter(
                    color: colors[index],
                    startAngle: startAngle,
                    sweepAngle: 2 * pi / colors.length,
                  ),
                ),
              );
            }),
            Center(
              child: Text(
                '${day.day}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
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
    }
  }

  Future<void> _toggleTodo(ToDoItem todo) async {
    final updatedTodo = todo.copyWith(isCompleted: !todo.isCompleted);
    await _saveTodo(updatedTodo);
  }

  Future<void> _saveSelectedDay(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date != null) {
      await prefs.setString('selectedDay', date.toIso8601String());
    } else {
      await prefs.remove('selectedDay');
    }
  }

  Future<void> _loadSelectedDay() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString('selectedDay');
    if (dateString != null) {
      final date = DateTime.tryParse(dateString);
      if (date != null && widget.initialDate == null) {
        setState(() {
          _selectedDay = date;
          _focusedDay = date;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: "To-Do List",
        studentName: _studentName,
        onLogoutPressed: _showLogoutConfirmationDialog,
      ),
      drawer: AppDrawer(studentName: _studentName),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2010, 10, 16),
                  lastDay: DateTime.utc(2030, 3, 14),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _saveSelectedDay(selectedDay);
                    _scrollToTask(_normalizeDate(selectedDay));
                    _showTaskDialog(_normalizeDate(selectedDay));
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(_normalizeDate(day), focusedDay);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF732525),
                          shape: BoxShape.circle,
                        ),
                        child: _buildCalendarDay(
                          _normalizeDate(day),
                          focusedDay,
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final colors = _dateColors[_normalizeDate(day)] ?? [];
                      if (colors.isEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A68CC),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      } else if (colors.length == 1) {
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.first,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      } else {
                        return Container(
                          margin: const EdgeInsets.all(4),
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ...List.generate(colors.length, (index) {
                                final startAngle =
                                    index * (2 * pi / colors.length);
                                return Positioned.fill(
                                  child: CustomPaint(
                                    painter: _SlicePainter(
                                      color: colors[index],
                                      startAngle: startAngle,
                                      sweepAngle: 2 * pi / colors.length,
                                    ),
                                  ),
                                );
                              }),
                              Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(color: Colors.white),
                    leftChevronIcon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                    ),
                    rightChevronIcon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: const TextStyle(color: Colors.white),
                    weekendStyle: const TextStyle(color: Colors.white),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _todoController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Add a new task...',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2A68CC),
                                    width: 2.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton(
                            onPressed: _addTodo,
                            backgroundColor: const Color(0xFF2A68CC),
                            mini: true,
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!_isAddingCustomCategory)
                        DropdownButtonFormField<String>(
                          value: _selectedTaskType,
                          decoration: InputDecoration(
                            labelText: 'Task Type',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: [
                            ..._availableCategories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }),
                            const DropdownMenuItem(
                              value: null,
                              child: Text(
                                'Add Custom Category',
                                style: TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              setState(() {
                                _isAddingCustomCategory = true;
                                _selectedTaskType = null;
                              });
                            } else {
                              setState(() {
                                _selectedTaskType = value;
                              });
                            }
                          },
                          dropdownColor: Colors.grey[800],
                        ),
                      if (_isAddingCustomCategory)
                        TextField(
                          controller: _customCategoryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'New Category Name',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: const BorderSide(
                                color: Color(0xFF2A68CC),
                                width: 2.0,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isAddingCustomCategory = false;
                                  _customCategoryController.clear();
                                });
                              },
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDay == null
                                  ? 'No date selected'
                                  : 'Selected: ${DateFormat('MMM dd, yyyy – hh:mm a').format(_selectedDay!)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDay ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (pickedDate != null) {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedDay != null
                                        ? TimeOfDay.fromDateTime(_selectedDay!)
                                        : TimeOfDay.now(),
                                  );
                                  DateTime finalDateTime = pickedDate;
                                  if (pickedTime != null) {
                                    finalDateTime = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                  }
                                  setState(() {
                                    _selectedDay = finalDateTime;
                                    _focusedDay = finalDateTime;
                                  });
                                  _saveSelectedDay(finalDateTime);
                                }
                              },
                              child: const Text(
                                'Select Date',
                                style: TextStyle(color: Color(0xFF2A68CC)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _todos.length,
                  itemBuilder: (context, index) {
                    final todo = _todos[index];
                    return Dismissible(
                      key: Key(todo.id ?? '${todo.title}$index'),
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) => _deleteTodo(todo.id),
                      child: AnimatedBuilder(
                        animation: _highlightController,
                        builder: (context, child) {
                          final colorValue = todo.isHighlighted
                              ? _highlightController.value
                              : 0.0;
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: todo.isHighlighted
                                  ? todo.color.withOpacity(colorValue * 0.3)
                                  : Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Card(
                              color: Colors.transparent,
                              elevation: 0,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: todo.color,
                                      width: 4.0,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  leading: Checkbox(
                                    value: todo.isCompleted,
                                    onChanged: (value) => _toggleTodo(todo),
                                    fillColor:
                                        MaterialStateProperty.resolveWith<
                                          Color
                                        >(
                                          (states) => todo.isCompleted
                                              ? const Color(0xFF2A68CC)
                                              : Colors.grey.shade700,
                                        ),
                                  ),
                                  title: Text(
                                    todo.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      decoration: todo.isCompleted
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                  subtitle: todo.dueDate != null
                                      ? Text(
                                          'Due: ${DateFormat('MMM dd, yyyy – hh:mm a').format(todo.dueDate!)}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        )
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (todo.taskType != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: todo.taskType == 'Exam'
                                                ? const Color(0xFF732525)
                                                : todo.taskType == 'Event'
                                                ? const Color(0xFF2A68CC)
                                                : Colors.grey.shade700,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            todo.taskType!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.white54,
                                        ),
                                        onPressed: () => _deleteTodo(todo.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF732525),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlicePainter extends CustomPainter {
  final Color color;
  final double startAngle;
  final double sweepAngle;

  _SlicePainter({
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ToDoItem {
  final String? id;
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;
  final String? taskType;
  final Color color;
  bool isHighlighted;

  ToDoItem({
    this.id,
    required this.title,
    required this.isCompleted,
    this.dueDate,
    this.taskType,
    required this.color,
    this.isHighlighted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'dueDate': dueDate?.toIso8601String(),
      'taskType': taskType,
      'color': color.value,
      'isHighlighted': isHighlighted,
    };
  }

  factory ToDoItem.fromMap(Map<String, dynamic> map, String id) {
    return ToDoItem(
      id: id,
      title: map['title'],
      isCompleted: map['isCompleted'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      taskType: map['taskType'],
      color: Color(map['color']),
      isHighlighted: map['isHighlighted'] ?? false,
    );
  }

  ToDoItem copyWith({
    String? title,
    bool? isCompleted,
    DateTime? dueDate,
    String? taskType,
    Color? color,
    bool? isHighlighted,
  }) {
    return ToDoItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      taskType: taskType ?? this.taskType,
      color: color ?? this.color,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }
}
