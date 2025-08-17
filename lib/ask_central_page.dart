import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:central_central_new/login_page.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:central_central_new/app_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FAQItem {
  final String id;
  final String question;
  final String answer;

  FAQItem({required this.id, required this.question, required this.answer});

  Map<String, dynamic> toMap() {
    return {'question': question, 'answer': answer};
  }

  factory FAQItem.fromMap(Map<String, dynamic> map, String id) {
    return FAQItem(
      id: id,
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
    );
  }
}

class AskCentralPage extends StatefulWidget {
  const AskCentralPage({Key? key}) : super(key: key);

  @override
  State<AskCentralPage> createState() => _AskCentralPageState();
}

class _AskCentralPageState extends State<AskCentralPage> {
  String _studentName = "User";
  bool _adminMode = false;
  bool _isLoading = false;
  final List<FAQItem> _faqs = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadStudentName();
    _loadAdminMode();
    _loadFAQs();
  }

  void _loadStudentName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _studentName =
            user.displayName ?? user.email?.split('@').first ?? "User";
      });
    }
  }

  Future<void> _loadAdminMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminMode = prefs.getBool('adminMode') ?? false;
    });
  }

  Future<void> _loadFAQs() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('faqs').get();
      setState(() {
        _faqs.clear();
        _faqs.addAll(
          snapshot.docs.map((doc) => FAQItem.fromMap(doc.data(), doc.id)),
        );
      });
    } catch (e) {
      String errorMessage = 'Error loading FAQs';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _loadFAQs),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addFAQ(FAQItem faq) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('faqs').add(faq.toMap());
      await _loadFAQs();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('FAQ added successfully')));
    } catch (e) {
      String errorMessage = 'Error adding FAQ';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: () => _addFAQ(faq)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFAQ(String id) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('faqs').doc(id).delete();
      setState(() {
        _faqs.removeWhere((faq) => faq.id == id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('FAQ deleted successfully')));
    } catch (e) {
      String errorMessage = 'Error deleting FAQ';
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
            onPressed: () => _deleteFAQ(id),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddFAQDialog() {
    final TextEditingController questionController = TextEditingController();
    final TextEditingController answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Add FAQ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Question',
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
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: answerController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Answer',
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
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Save',
                style: TextStyle(color: Color(0xFF2A68CC)),
              ),
              onPressed: () {
                if (questionController.text.trim().isEmpty ||
                    answerController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in both question and answer'),
                    ),
                  );
                  return;
                }
                final newFAQ = FAQItem(
                  id: '', // Firestore will generate ID
                  question: questionController.text.trim(),
                  answer: answerController.text.trim(),
                );
                Navigator.of(context).pop();
                _addFAQ(newFAQ);
              },
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color.fromARGB(255, 17, 17, 17),
          appBar: AppHeader(
            title: "Ask Central",
            studentName: _studentName,
            onLogoutPressed: _showLogoutConfirmationDialog,
          ),
          drawer: AppDrawer(studentName: _studentName),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF732525),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ask Central',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Find answers to common questions below.',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      _faqs.isEmpty
                          ? const Center(
                              child: Text(
                                'No FAQs available. Admins have not added any FAQs.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Column(
                              children: _faqs
                                  .map(
                                    (faq) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 15.0,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade700,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: ExpansionTile(
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  faq.question,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (_adminMode)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      _deleteFAQ(faq.id),
                                                ),
                                            ],
                                          ),
                                          collapsedBackgroundColor:
                                              Colors.grey[800],
                                          backgroundColor: Colors.grey[800],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: Colors.grey.shade700,
                                              width: 1.0,
                                            ),
                                          ),
                                          collapsedShape:
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                side: BorderSide(
                                                  color: Colors.grey.shade700,
                                                  width: 1.0,
                                                ),
                                              ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                16.0,
                                              ),
                                              child: Text(
                                                faq.answer,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ],
                  ),
                ),
          floatingActionButton: _adminMode
              ? FloatingActionButton(
                  onPressed: _showAddFAQDialog,
                  backgroundColor: const Color(0xFF732525),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
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
    );
  }
}
