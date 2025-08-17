import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map, String id) {
    return NotificationItem(
      id: id,
      title: map['title'] ?? 'Untitled',
      body: map['body'] ?? '',
      timestamp: DateTime.parse(
        map['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isRead: map['isRead'] ?? false,
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<NotificationItem> _notifications = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    if (!mounted) return; // Prevent state updates if widget is disposed
    await _loadNotifications();
    await _setupPushNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
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
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      if (!mounted) return;
      setState(() {
        _notifications.clear();
        _notifications.addAll(
          snapshot.docs.map(
            (doc) => NotificationItem.fromMap(doc.data(), doc.id),
          ),
        );
      });
    } catch (e) {
      String errorMessage = 'Error loading notifications';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadNotifications,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setupPushNotifications() async {
    if (!mounted) return;
    final messaging = FirebaseMessaging.instance;
    try {
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized) {
        return;
      }
      final token = await messaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!mounted) return;
        final notification = message.notification;
        if (notification != null) {
          final newNotification = NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: notification.title ?? 'New Notification',
            body: notification.body ?? '',
            timestamp: DateTime.now(),
          );
          _addNotification(newNotification);
        }
      });
    } catch (e) {
      String errorMessage = 'Error setting up push notifications';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _setupPushNotifications,
            ),
          ),
        );
      }
    }
  }

  Future<void> _addNotification(NotificationItem notification) async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
      await _loadNotifications();
    } catch (e) {
      String errorMessage = 'Error saving notification';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _addNotification(notification),
            ),
          ),
        );
      }
    }
  }

  Future<void> _dismissNotification(String id) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(id)
          .delete();
      if (mounted) {
        setState(() {
          _notifications.removeWhere((item) => item.id == id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notification dismissed')));
      }
    } catch (e) {
      String errorMessage = 'Error dismissing notification';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _dismissNotification(id),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleReadStatus(String id) async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final index = _notifications.indexWhere((item) => item.id == id);
      if (index != -1) {
        final updatedNotification = NotificationItem(
          id: _notifications[index].id,
          title: _notifications[index].title,
          body: _notifications[index].body,
          timestamp: _notifications[index].timestamp,
          isRead: !_notifications[index].isRead,
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(id)
            .update({'isRead': updatedNotification.isRead});
        if (mounted) {
          setState(() {
            _notifications[index] = updatedNotification;
          });
        }
      }
    } catch (e) {
      String errorMessage = 'Error updating notification';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _toggleReadStatus(id),
            ),
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 17, 17, 17),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight * 1.5),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF732525)),
              ),
            )
          : _notifications.isEmpty
          ? const Center(
              child: Text(
                'No new notifications.',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _dismissNotification(notification.id);
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    color: notification.isRead
                        ? Colors.black.withOpacity(0.3)
                        : const Color(0xFF1D283C),
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: notification.isRead
                            ? Colors.grey.shade700
                            : Colors.blueAccent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12.0),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          notification.isRead
                              ? Icons.mark_email_read
                              : Icons.mark_email_unread,
                          color: notification.isRead
                              ? Colors.white54
                              : Colors.lightGreenAccent,
                        ),
                        onPressed: () => _toggleReadStatus(notification.id),
                      ),
                      onTap: () {
                        if (!notification.isRead) {
                          _toggleReadStatus(notification.id);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tapped on: ${notification.title}'),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
