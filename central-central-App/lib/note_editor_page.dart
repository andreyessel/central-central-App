import 'package:flutter/material.dart';
import 'package:central_central_new/notes_page.dart';

class NoteEditorPage extends StatefulWidget {
  final Note initialNote;

  const NoteEditorPage({super.key, required this.initialNote});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contentController.text = widget.initialNote.content;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final updatedNote = Note(
      id: widget.initialNote.id,
      noteName: widget.initialNote.noteName,
      category: widget.initialNote.category,
      color: widget.initialNote.color,
      content: _contentController.text,
      filePath: widget.initialNote.filePath,
    );

    Navigator.of(context).pop(updatedNote);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text(
          widget.initialNote.noteName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF732525),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _contentController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            hintText: 'Start typing your note here...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
