import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:central_central_new/login_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:central_central_new/app_drawer.dart';
import 'package:central_central_new/app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class CampusServicesPage extends StatefulWidget {
  const CampusServicesPage({super.key});

  @override
  State<CampusServicesPage> createState() => _CampusServicesPageState();
}

class _CampusServicesPageState extends State<CampusServicesPage> {
  String _studentName = "User";
  bool _isAdmin = false;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _loadStudentName();
    _loadAdminStatus();
    _loadServices();
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

  Future<void> _loadAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('adminMode') ?? false;
    });
  }

  void _loadServices() {
    FirebaseFirestore.instance
        .collection('services')
        .snapshots()
        .listen(
          (snapshot) {
            setState(() {
              _services = snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'title': data['title'] ?? '',
                  'phoneNumber': data['phoneNumber'] ?? '',
                  'imageUrl': data['imageUrl'],
                };
              }).toList();
            });
          },
          onError: (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading services: $e')),
            );
          },
        );
  }

  void _showAddServiceDialog() {
    final titleController = TextEditingController();
    final phoneNumberController = TextEditingController();
    final imageUrlController = TextEditingController();

    Future<void> _pickImage() async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null && context.mounted) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final storageRef = FirebaseStorage.instance
              .ref()
              .child('service_images')
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
          title: const Text(
            'Add Service',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Service Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2A68CC)),
                  ),
                ),
              ),
              TextField(
                controller: phoneNumberController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2A68CC)),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: imageUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Menu Image URL (optional)',
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

                final title = titleController.text.trim();
                final phoneNumber = phoneNumberController.text.trim();
                final imageUrl = imageUrlController.text.trim().isEmpty
                    ? null
                    : imageUrlController.text.trim();

                if (title.isEmpty || phoneNumber.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Title and phone number are required'),
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('services').add({
                    'title': title,
                    'phoneNumber': phoneNumber,
                    'imageUrl': imageUrl,
                    'createdBy': user.uid,
                  });
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding service: $e')),
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

  void _showDeleteServiceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Delete Service',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: _services.isEmpty
              ? const Text(
                  'No services available to delete',
                  style: TextStyle(color: Colors.white70),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      final service = _services[index];
                      return ListTile(
                        title: Text(
                          service['title'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('services')
                                .doc(service['id'])
                                .delete();
                            Navigator.of(context).pop();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting service: $e'),
                              ),
                            );
                          }
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

  Future<void> _launchUrl(String urlString, {String? fallbackUrl}) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: "Campus Services",
        studentName: _studentName,
        onLogoutPressed: _showLogoutConfirmationDialog,
      ),
      drawer: AppDrawer(studentName: _studentName),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildServiceButton(
                      "IKILNA Food and Services",
                      ['assets/images/Iklina Menu.png'],
                      onTapRedirect: () => _launchUrl('tel:0268140002'),
                    ),
                    const SizedBox(height: 15),
                    _buildServiceButton(
                      "CHAMPION Foods and Services",
                      [
                        'assets/images/placeholder_menu_3.png',
                        'assets/images/placeholder_menu_4.png',
                      ],
                      onTapRedirect: () => _launchUrl('tel:0541788088'),
                    ),
                    const SizedBox(height: 15),
                    _buildServiceButton(
                      "JoePsalms Food and Services",
                      [
                        'assets/images/placeholder_menu_5.png',
                        'assets/images/placeholder_menu_6.png',
                      ],
                      onTapRedirect: () => _launchUrl('tel:11223344'),
                    ),
                    ..._services.map((service) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: _buildServiceButton(
                          service['title'],
                          service['imageUrl'] != null &&
                                  service['imageUrl'].isNotEmpty
                              ? [service['imageUrl']]
                              : [],
                          onTapRedirect: service['phoneNumber'].isNotEmpty
                              ? () =>
                                    _launchUrl('tel:${service['phoneNumber']}')
                              : null,
                        ),
                      );
                    }).toList(),
                    if (_isAdmin) ...[
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
                                borderRadius: BorderRadius.circular(15),
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.5),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  onPressed: _showAddServiceDialog,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: Material(
                                color: const Color(0xFF732525),
                                borderRadius: BorderRadius.circular(15),
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.5),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  onPressed: _showDeleteServiceDialog,
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
    );
  }

  Widget _buildServiceButton(
    String title,
    List<String> menuImagePaths, {
    VoidCallback? onTapRedirect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade700, width: 1.0),
      ),
      child: ExpansionTile(
        key: PageStorageKey(title),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTapRedirect != null)
              InkWell(
                onTap: onTapRedirect,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.phone,
                    color: Colors.lightBlueAccent,
                    size: 20,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.restaurant_menu, color: Colors.white70, size: 20),
          ],
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: menuImagePaths.isEmpty
                  ? [
                      const Center(
                        child: Text(
                          'No menu available',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ]
                  : menuImagePaths.map((path) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: path.startsWith('http')
                            ? Image.network(
                                path,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey[800],
                                    child: Center(
                                      child: Text(
                                        'Error loading image: $path',
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
                            : Image.asset(
                                path,
                                fit: BoxFit.contain,
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
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
