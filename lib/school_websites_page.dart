import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:central_central_new/login_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:central_central_new/app_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class WebsiteItem {
  final String id;
  final String name;
  final String url;
  final String? imageUrl;

  WebsiteItem({
    required this.id,
    required this.name,
    required this.url,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'url': url, 'imageUrl': imageUrl};
  }

  factory WebsiteItem.fromMap(Map<String, dynamic> map, String id) {
    return WebsiteItem(
      id: id,
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }
}

class SchoolWebsitesPage extends StatefulWidget {
  const SchoolWebsitesPage({super.key});

  @override
  State<SchoolWebsitesPage> createState() => _SchoolWebsitesPageState();
}

class _SchoolWebsitesPageState extends State<SchoolWebsitesPage> {
  String _studentName = "User";
  bool _adminMode = false;
  bool _isLoading = false;
  final List<WebsiteItem> _customWebsites = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadStudentName();
    _loadAdminMode();
    _loadCustomWebsites();
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

  Future<void> _loadCustomWebsites() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('websites').get();
      setState(() {
        _customWebsites.clear();
        _customWebsites.addAll(
          snapshot.docs.map((doc) => WebsiteItem.fromMap(doc.data(), doc.id)),
        );
      });
    } catch (e) {
      String errorMessage = 'Error loading websites';
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
            onPressed: _loadCustomWebsites,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImageToStorage(XFile image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final ref = _storage.ref().child(
        'website_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}',
      );
      final uploadTask = await ref.putFile(File(image.path));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      String errorMessage = 'Error uploading image';
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
            onPressed: () => _uploadImageToStorage(image),
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _addWebsite(WebsiteItem website, XFile? image) async {
    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (image != null) {
        imageUrl = await _uploadImageToStorage(image);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }
      final updatedWebsite = WebsiteItem(
        id: website.id,
        name: website.name,
        url: website.url,
        imageUrl: imageUrl,
      );
      await _firestore.collection('websites').add(updatedWebsite.toMap());
      await _loadCustomWebsites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Website added successfully')),
      );
    } catch (e) {
      String errorMessage = 'Error adding website';
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
            onPressed: () => _addWebsite(website, image),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWebsite(String id) async {
    setState(() => _isLoading = true);
    try {
      final websiteDoc = await _firestore.collection('websites').doc(id).get();
      if (websiteDoc.exists && websiteDoc.data()!['imageUrl'] != null) {
        await _storage.refFromURL(websiteDoc.data()!['imageUrl']).delete();
      }
      await _firestore.collection('websites').doc(id).delete();
      setState(() {
        _customWebsites.removeWhere((website) => website.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Website deleted successfully')),
      );
    } catch (e) {
      String errorMessage = 'Error deleting website';
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
            onPressed: () => _deleteWebsite(id),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddWebsiteDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController urlController = TextEditingController();
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Add Website',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Website Name',
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
                controller: urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Website Link',
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
              TextButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      selectedImage = pickedFile;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Image selected: ${pickedFile.name}'),
                      ),
                    );
                  }
                },
                child: Text(
                  selectedImage == null
                      ? 'Pick Website Image (Optional)'
                      : 'Image Selected',
                  style: TextStyle(
                    color: selectedImage == null
                        ? Colors.white70
                        : Color(0xFF2A68CC),
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
                if (nameController.text.trim().isEmpty ||
                    urlController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in website name and link'),
                    ),
                  );
                  return;
                }
                final newWebsite = WebsiteItem(
                  id: '', // Firestore will generate ID
                  name: nameController.text.trim(),
                  url: urlController.text.trim(),
                  imageUrl: null, // Updated in _addWebsite after image upload
                );
                Navigator.of(context).pop();
                _addWebsite(newWebsite, selectedImage);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteWebsiteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Delete Website',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: _customWebsites.isEmpty
              ? const Text(
                  'No websites available to delete',
                  style: TextStyle(color: Colors.white70),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _customWebsites.length,
                    itemBuilder: (context, index) {
                      final website = _customWebsites[index];
                      return ListTile(
                        title: Text(
                          website.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          await _deleteWebsite(website.id);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
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

  Future<void> _launchUrl(String urlString, {String? fallbackUrl}) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (fallbackUrl != null) {
      final Uri fallbackUri = Uri.parse(fallbackUrl);
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch fallback URL: $fallbackUri'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch URL: $uri')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color.fromARGB(255, 17, 17, 17),
          appBar: AppHeader(
            title: "School Websites",
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
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 15),
                              _buildWebsiteButton(
                                "VCAMPUS",
                                ['assets/images/Vcampus.png'],
                                onTapRedirect: () => _launchUrl(
                                  'https://vcampus.central.edu.gh:42784/course/view.php?id=586',
                                ),
                                redirectText: "GO TO SITE",
                                isAsset: true,
                              ),
                              const SizedBox(height: 15),
                              _buildWebsiteButton(
                                "SFP",
                                ['assets/images/SFP.png'],
                                onTapRedirect: () =>
                                    _launchUrl('http://sfp.central.edu.gh/'),
                                redirectText: "GO TO SITE",
                                isAsset: true,
                              ),
                              const SizedBox(height: 15),
                              _buildWebsiteButton(
                                "SIP",
                                ['assets/images/SIP.png'],
                                onTapRedirect: () =>
                                    _launchUrl('https://osissip.osis.online/'),
                                redirectText: "GO TO SITE",
                                isAsset: true,
                              ),
                              const SizedBox(height: 15),
                              ..._customWebsites
                                  .map(
                                    (website) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 15.0,
                                      ),
                                      child: _buildWebsiteButton(
                                        website.name,
                                        website.imageUrl != null
                                            ? [website.imageUrl!]
                                            : [],
                                        onTapRedirect: () =>
                                            _launchUrl(website.url),
                                        redirectText: "GO TO SITE",
                                        websiteId: website.id,
                                        isAsset: false,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              if (_adminMode) ...[
                                const SizedBox(height: 15),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: Material(
                                          color: const Color(0xFF732525),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          elevation: 4,
                                          shadowColor: Colors.black.withOpacity(
                                            0.5,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            onPressed: _showAddWebsiteDialog,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: Material(
                                          color: const Color(0xFF732525),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          elevation: 4,
                                          shadowColor: Colors.black.withOpacity(
                                            0.5,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            onPressed: _showDeleteWebsiteDialog,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildWebsiteButton(
    String title,
    List<String> imageUrls, {
    required VoidCallback onTapRedirect,
    required String redirectText,
    String? websiteId,
    required bool isAsset,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade700, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF8E1919),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: onTapRedirect,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Text(
                redirectText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: imageUrls.isNotEmpty
                  ? imageUrls.map((path) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: isAsset
                            ? Image.asset(
                                path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 150,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey[800],
                                    child: Center(
                                      child: Text(
                                        'Error loading image: $path\n(Placeholder)',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Image.network(
                                path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 150,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey[800],
                                    child: Center(
                                      child: Text(
                                        'Error loading image: $path\n(Placeholder)',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      );
                    }).toList()
                  : [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0),
                        child: Text(
                          'No image available',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}
