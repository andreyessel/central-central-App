import 'package:flutter/material.dart';
import 'package:central_central_new/add_note_modal.dart';
import 'package:central_central_new/note_editor_page.dart';
import 'package:open_filex/open_filex.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:central_central_new/login_page.dart';
import 'package:central_central_new/app_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';

class Note {
  String? id;
  String noteName;
  String category;
  Color color;
  String content;
  String? filePath;

  Note({
    this.id,
    required this.noteName,
    required this.category,
    required this.color,
    this.content = '',
    this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'noteName': noteName,
      'category': category,
      'color': color.value.toRadixString(16),
      'content': content,
      'filePath': filePath,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, String id) {
    return Note(
      id: id,
      noteName: map['noteName'] ?? '',
      category: map['category'] ?? 'No category',
      color: Color(int.parse(map['color'] ?? 'FF0000FF', radix: 16)),
      content: map['content'] ?? '',
      filePath: map['filePath'],
    );
  }
}

class NotesPage extends StatefulWidget {
  final String studentName;
  const NotesPage({super.key, required this.studentName});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final List<Note> _notes = [];
  List<String> _categories = ['No category'];
  String? _selectedCategoryFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
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
          .collection('notes')
          .get();

      setState(() {
        _notes.clear();
        _notes.addAll(
          snapshot.docs.map((doc) => Note.fromMap(doc.data(), doc.id)),
        );

        _categories = ['No category'];
        _categories.addAll(
          _notes.map((note) => note.category).toSet().toList(),
        );
        _categories.sort((a, b) {
          if (a == 'No category') return -1;
          if (b == 'No category') return 1;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
      });
    } catch (e) {
      String errorMessage = 'Error loading notes';
      if (e is FirebaseException) {
        errorMessage = e.code == 'unavailable'
            ? 'No internet connection. Please try again.'
            : 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(label: 'Retry', onPressed: _loadNotes),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote(Note note) async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (note.id == null) {
        final docRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .add(note.toMap());
        note = Note(
          id: docRef.id,
          noteName: note.noteName,
          category: note.category,
          color: note.color,
          content: note.content,
          filePath: note.filePath,
        );
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(note.id)
            .set(note.toMap(), SetOptions(merge: true));
      }
      await _loadNotes();
    } catch (e) {
      String errorMessage = 'Error saving note';
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
            onPressed: () => _saveNote(note),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote(String? id) async {
    setState(() => _isLoading = true);
    if (id == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .doc(id)
          .delete();
      await _loadNotes();
    } catch (e) {
      String errorMessage = 'Error deleting note';
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
            onPressed: () => _deleteNote(id),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _duplicateNote(Note note) async {
    final duplicatedNote = Note(
      noteName: '${note.noteName} (Copy)',
      category: note.category,
      color: note.color,
      content: note.content,
      filePath: note.filePath,
    );
    await _saveNote(duplicatedNote);
  }

  Future<void> _editNoteMetadata(Note note) async {
    final TextEditingController noteNameController = TextEditingController(
      text: note.noteName,
    );
    final TextEditingController categoryController = TextEditingController(
      text: note.category,
    );
    String? newCategory = note.category;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text(
          'Edit Note Metadata',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noteNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Note Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: newCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _categories
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(
                        cat,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                newCategory = value;
              },
              dropdownColor: Colors.grey.shade800,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: categoryController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New Category (optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop({
                'noteName': noteNameController.text,
                'category': categoryController.text.isNotEmpty
                    ? categoryController.text
                    : newCategory,
              });
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF2A68CC)),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedNote = Note(
        id: note.id,
        noteName: result['noteName'],
        category: result['category'],
        color: note.color,
        content: note.content,
        filePath: note.filePath,
      );
      await _saveNote(updatedNote);
      if (!_categories.contains(result['category']) &&
          result['category'].isNotEmpty) {
        setState(() {
          _categories.add(result['category']);
          _categories.sort((a, b) {
            if (a == 'No category') return -1;
            if (b == 'No category') return 1;
            return a.toLowerCase().compareTo(b.toLowerCase());
          });
        });
      }
    }
  }

  void _showAddNoteMenu() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddNoteModal(existingCategories: _categories),
    );

    if (result != null && result is Map<String, dynamic>) {
      if (result['note'] != null) {
        Note note = result['note'] as Note;
        note = Note(
          id: note.id,
          noteName: note.noteName,
          category: note.category,
          color: Color.fromARGB(
            255,
            _random.nextInt(256),
            _random.nextInt(256),
            _random.nextInt(256),
          ),
          content: note.content,
          filePath: note.filePath,
        );
        if (note.filePath != null) {
          await _saveNote(note);
        } else {
          final updatedNote = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoteEditorPage(initialNote: note),
            ),
          );
          if (updatedNote != null && updatedNote is Note) {
            await _saveNote(updatedNote);
          }
        }
      }
      if (result['newCategory'] != null) {
        setState(() {
          final newCat = result['newCategory'] as String;
          if (!_categories.contains(newCat)) {
            _categories.add(newCat);
            _categories.sort((a, b) {
              if (a == 'No category') return -1;
              if (b == 'No category') return 1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });
          }
        });
      }
    }
  }

  List<Note> get _filteredNotes {
    return _notes.where((note) {
      final matchesSearch = note.noteName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategoryFilter == null ||
          _selectedCategoryFilter == 'All Notes' ||
          note.category == _selectedCategoryFilter;
      return matchesSearch && matchesCategory;
    }).toList()..sort(
      (a, b) => a.noteName.toLowerCase().compareTo(b.noteName.toLowerCase()),
    );
  }

  Widget _noteTile(Note note) {
    final borderColor = note.color;

    return GestureDetector(
      onTap: () async {
        if (note.filePath != null && note.filePath!.isNotEmpty) {
          final result = await OpenFilex.open(note.filePath!);
          if (result.type != ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: ${result.message}')),
            );
          }
        } else {
          final updatedNote = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoteEditorPage(initialNote: note),
            ),
          );
          if (updatedNote != null &&
              updatedNote is Note &&
              updatedNote.id == note.id) {
            await _saveNote(updatedNote);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Stack(
          children: [
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.noteName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white70,
                        ),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            _deleteNote(note.id);
                          } else if (value == 'share') {
                            if (note.filePath != null &&
                                note.filePath!.isNotEmpty) {
                              await Share.shareXFiles([
                                XFile(note.filePath!),
                              ], text: 'Sharing note: ${note.noteName}');
                            } else {
                              await Share.share(
                                'Note: ${note.noteName}\nContent: ${note.content}',
                              );
                            }
                          } else if (value == 'edit') {
                            if (note.filePath != null) {
                              await _editNoteMetadata(note);
                            } else {
                              final updatedNote = await Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          NoteEditorPage(initialNote: note),
                                    ),
                                  );
                              if (updatedNote != null &&
                                  updatedNote is Note &&
                                  updatedNote.id == note.id) {
                                await _saveNote(updatedNote);
                              }
                            }
                          } else if (value == 'duplicate') {
                            await _duplicateNote(note);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return [
                            const PopupMenuItem<String>(
                              value: 'share',
                              child: Text('Share'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'duplicate',
                              child: Text('Duplicate'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Category: ${note.category}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (note.content.isNotEmpty && note.filePath == null)
                    Text(
                      note.content.split('\n').first,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
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
    try {
      setState(() => _isLoading = true);
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
    List<String> displayCategories = [
      'All Notes',
      ..._categories.where((cat) => cat != 'No category' && cat != 'All Notes'),
    ];
    if (_categories.contains('No category')) {
      displayCategories.insert(1, 'No category');
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color.fromARGB(255, 17, 17, 17),
          appBar: AppHeader(
            title: "Notes Organizer",
            studentName: widget.studentName,
            onLogoutPressed: _showLogoutConfirmationDialog,
          ),
          drawer: AppDrawer(studentName: widget.studentName),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 5.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: Colors.grey.shade700,
                          width: 1.0,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategoryFilter ?? 'All Notes',
                          dropdownColor: Colors.grey.shade800,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCategoryFilter =
                                  (newValue == 'All Notes') ? null : newValue;
                            });
                          },
                          items: displayCategories
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF732525),
                            ),
                          ),
                        )
                      : _searchQuery.isNotEmpty && _filteredNotes.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching notes found.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : _filteredNotes.isEmpty && _searchQuery.isEmpty
                      ? const Center(
                          child: Text(
                            'No notes added yet.\nClick the "+" button to add your first note.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(10),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (_, index) =>
                              _noteTile(_filteredNotes[index]),
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddNoteMenu,
            backgroundColor: const Color(0xFF732525),
            child: const Icon(Icons.add, color: Colors.white),
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
    );
  }
}
