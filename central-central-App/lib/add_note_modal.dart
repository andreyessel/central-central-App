import 'package:flutter/material.dart';
import 'package:central_central_new/notes_page.dart';
import 'package:central_central_new/note_editor_page.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

class AddNoteModal extends StatefulWidget {
  final List<String> existingCategories;
  const AddNoteModal({super.key, required this.existingCategories});

  @override
  State<AddNoteModal> createState() => _AddNoteModalState();
}

class _AddNoteModalState extends State<AddNoteModal>
    with SingleTickerProviderStateMixin {
  final _noteNameController = TextEditingController();
  final _newCategoryController = TextEditingController();

  String? _selectedCategory;
  bool _isAddingCategory = false;
  final Color _currentColor = Colors.blue;

  AnimationController? _flashController;
  Animation<Color?>? _borderFlashAnimation;

  List<String> _dropdownCategories = [];

  @override
  void initState() {
    super.initState();

    _dropdownCategories = [
      'No category',
      ...widget.existingCategories.where(
        (cat) => cat != 'Add category' && cat != 'No category',
      ),
    ];
    _dropdownCategories.sort((a, b) {
      if (a == 'No category') return -1;
      if (b == 'No category') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    _flashController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          setState(() {});
        });

    _borderFlashAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red,
    ).animate(_flashController!);
  }

  @override
  void dispose() {
    _noteNameController.dispose();
    _newCategoryController.dispose();
    _flashController?.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    String labelText,
    TextEditingController controller,
  ) {
    bool shouldFlashBorder =
        controller.text.isEmpty &&
        _flashController != null &&
        _flashController!.isAnimating;

    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: shouldFlashBorder
              ? _borderFlashAnimation?.value ?? Colors.transparent
              : Colors.grey.shade700,
          width: 2.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Color(0xFF2A68CC), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: shouldFlashBorder
              ? _borderFlashAnimation?.value ?? Colors.red
              : Colors.red,
          width: 2.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: shouldFlashBorder
              ? _borderFlashAnimation?.value ?? Colors.red
              : Colors.red,
          width: 2.0,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: shouldFlashBorder
              ? _borderFlashAnimation?.value ?? Colors.transparent
              : Colors.grey.shade700,
          width: 2.0,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 15.0,
        horizontal: 15.0,
      ),
    );
  }

  bool _validateAndFlashEmptyFields() {
    bool noteNameEmpty = _noteNameController.text.isEmpty;
    bool newCategoryEmpty =
        _isAddingCategory && _newCategoryController.text.isEmpty;
    bool categoryNotSelected = !_isAddingCategory && _selectedCategory == null;

    bool anyTextFieldEmpty = noteNameEmpty || newCategoryEmpty;
    bool validationFailed = anyTextFieldEmpty || categoryNotSelected;

    if (validationFailed) {
      if (anyTextFieldEmpty || categoryNotSelected) {
        _flashController?.stop();
        _flashController?.reset();
        _flashController?.repeat(reverse: true);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _flashController?.stop();
            _flashController?.reset();
          }
        });
      }

      String message = '';
      if (anyTextFieldEmpty) {
        message = 'Please fill in all required text fields.';
      } else if (categoryNotSelected) {
        message = 'Please select a category or add a new one.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }

    _flashController?.stop();
    _flashController?.reset();
    return true;
  }

  void _addNoteFromFile() async {
    try {
      if (!_validateAndFlashEmptyFields()) {
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        final newCategory = _isAddingCategory
            ? _newCategoryController.text
            : null;
        final selectedCategoryFinal =
            _isAddingCategory && newCategory != null && newCategory.isNotEmpty
            ? newCategory
            : (_selectedCategory ?? 'No category');

        final newNote = Note(
          id: null,
          noteName: _noteNameController.text.isEmpty
              ? fileName
              : _noteNameController.text,
          category: selectedCategoryFinal,
          color: _currentColor,
          filePath: filePath,
          content: '',
        );

        Navigator.of(context).pop({
          'note': newNote,
          if (newCategory != null && newCategory.isNotEmpty)
            'newCategory': newCategory,
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File picking canceled.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  void _addNoteAndReturnDataAndNavigateToEditor() async {
    if (_validateAndFlashEmptyFields()) {
      final newCategory = _isAddingCategory
          ? _newCategoryController.text
          : null;
      final selectedCategoryFinal =
          _isAddingCategory && newCategory != null && newCategory.isNotEmpty
          ? newCategory
          : (_selectedCategory ?? 'No category');

      final newNote = Note(
        id: null,
        noteName: _noteNameController.text,
        category: selectedCategoryFinal,
        color: _currentColor,
        content: '',
      );

      final updatedNote = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NoteEditorPage(initialNote: newNote),
        ),
      );

      if (updatedNote != null && updatedNote is Note) {
        Navigator.of(context).pop({
          'note': updatedNote,
          if (newCategory != null && newCategory.isNotEmpty)
            'newCategory': newCategory,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF292929),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const Text(
                'Add New Note',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _noteNameController,
                decoration: _inputDecoration('Note Name', _noteNameController),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 15),
              _isAddingCategory
                  ? TextField(
                      controller: _newCategoryController,
                      decoration: _inputDecoration(
                        'New Category Name',
                        _newCategoryController,
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        setState(() {});
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              (_selectedCategory == null) &&
                                  (_flashController != null &&
                                      _flashController!.isAnimating)
                              ? _borderFlashAnimation?.value ??
                                    Colors.transparent
                              : Colors.grey.shade700,
                          width: 2.0,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedCategory,
                          hint: const Text(
                            'Select Category',
                            style: TextStyle(color: Colors.white70),
                          ),
                          dropdownColor: Colors.grey.shade800,
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          },
                          items: _dropdownCategories
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
              const SizedBox(height: 15),
              if (!_isAddingCategory)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAddingCategory = true;
                      _selectedCategory = null;
                    });
                  },
                  child: const Text(
                    'Or Add New Category',
                    style: TextStyle(color: Color(0xFF2A68CC)),
                  ),
                ),
              if (_isAddingCategory)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAddingCategory = false;
                      _newCategoryController.clear();
                      _selectedCategory = null;
                    });
                  },
                  child: const Text(
                    'Cancel Add Category',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addNoteFromFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF732525),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Fetch Notes', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addNoteAndReturnDataAndNavigateToEditor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A68CC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Make your own notes',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
