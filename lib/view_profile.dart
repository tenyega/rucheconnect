import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ViewProfilePage extends StatefulWidget {
  final String? apiculteurId; // Optional ID for non-registered apiculteurs

  const ViewProfilePage({
    Key? key,
    this.apiculteurId,
  }) : super(key: key);

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Apiculteur data map
  Map<String, dynamic> userData = {
    'login': '',
    'nom': '',
    'prenom': '',
    'email': '',
    'address': '',
    'pwd': '',
    'joinedDate': '',
    'isRegistered': false, // Flag to track if user is registered
  };

  // ID of the current apiculteur
  String apiculteurId = '';

  bool isEditing = false;
  bool isLoading = true;
  bool isCurrentUser = false; // Flag to check if viewing own profile
  late TextEditingController loginController;
  late TextEditingController nomController;
  late TextEditingController prenomController;
  late TextEditingController emailController;
  late TextEditingController addressController;
  late TextEditingController pwdController;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    loginController = TextEditingController();
    nomController = TextEditingController();
    prenomController = TextEditingController();
    emailController = TextEditingController();
    addressController = TextEditingController();
    pwdController = TextEditingController();

    // Check if we're viewing a specific apiculteur or the current user
    if (widget.apiculteurId != null) {
      apiculteurId = widget.apiculteurId!;
      _loadSpecificApiculteur(apiculteurId);
      isCurrentUser = false;
    } else {
      _loadCurrentUserData();
      isCurrentUser = true;
    }
  }

  @override
  void dispose() {
    loginController.dispose();
    nomController.dispose();
    prenomController.dispose();
    emailController.dispose();
    addressController.dispose();
    pwdController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current Firebase user
      final User? user = _auth.currentUser;

      if (user != null) {
        // User is authenticated, find their apiculteur record
        final String email = user.email ?? '';
        await _findApiculteurByEmail(email);
      } else {
        // No authenticated user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No authenticated user found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _findApiculteurByEmail(String email) async {
    final apiculteursRef = _database.child('apiculteurs');
    final snapshot = await apiculteursRef.get();

    if (snapshot.exists && snapshot.value != null) {
      final Map<dynamic, dynamic> apiculteurs = snapshot.value as Map<dynamic, dynamic>;

      // Find the apiculteur with the matching email
      String? foundId;
      Map<dynamic, dynamic>? foundData;

      apiculteurs.forEach((key, value) {
        if (value is Map && value['email'] == email) {
          foundId = key.toString();
          foundData = value as Map<dynamic, dynamic>;
        }
      });

      if (foundId != null && foundData != null) {
        apiculteurId = foundId!;
        _updateUserDataFromFirebase(foundData!);
        userData['isRegistered'] = true;
      } else {
        // Handle case where apiculteur is not found
        if(email!= 'test@gmail.com'){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Apiculteur not found for this account'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSpecificApiculteur(String id) async {
    setState(() {
      isLoading = true;
    });

    try {
      final apiculteurRef = _database.child('apiculteurs/$id');
      final snapshot = await apiculteurRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> foundData = snapshot.value as Map<dynamic, dynamic>;
        _updateUserDataFromFirebase(foundData);

        // Check if this apiculteur is registered with Firebase Auth
        userData['isRegistered'] = false; // Default to false

        // Try to find if this email is registered in Firebase Auth
        try {
          final result = await FirebaseAuth.instance.fetchSignInMethodsForEmail(userData['email']);
          userData['isRegistered'] = result.isNotEmpty;
        } catch (e) {
          // Ignore errors when checking registration status
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Apiculteur not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading apiculteur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateUserDataFromFirebase(Map<dynamic, dynamic> data) {
    setState(() {
      userData['login'] = data['login'] ?? '';
      userData['nom'] = data['nom'] ?? '';
      userData['prenom'] = data['prenom'] ?? '';
      userData['email'] = data['email'] ?? '';
      userData['address'] = data['address'] ?? '';
      userData['pwd'] = data['pwd']?.toString() ?? '';
      userData['joinedDate'] = data['joinedDate'] ?? 'January 2023'; // Default or fetch from data

      // Set up the controllers with current values
      loginController.text = userData['login'];
      nomController.text = userData['nom'];
      prenomController.text = userData['prenom'];
      emailController.text = userData['email'];
      addressController.text = userData['address'];
      pwdController.text = userData['pwd'];

      isLoading = false;
    });
  }

  void toggleEditMode() {
    // Only allow editing for the current user
    if (!isCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You can only edit your own profile'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      if (isEditing) {
        _saveApiculteurData();
      }
      isEditing = !isEditing;
    });
  }

  Future<void> _saveApiculteurData() async {
    try {
      if (apiculteurId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No apiculteur ID found to update'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update local userData
      userData['login'] = loginController.text;
      userData['nom'] = nomController.text;
      userData['prenom'] = prenomController.text;
      userData['email'] = emailController.text;
      userData['address'] = addressController.text;
      userData['pwd'] = pwdController.text;

      // Update profile in Firebase Realtime Database
      await _database.child('apiculteurs/$apiculteurId').update({
        'login': userData['login'],
        'nom': userData['nom'],
        'prenom': userData['prenom'],
        'email': userData['email'],
        'address': userData['address'],
        'pwd': userData['pwd'],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    // Show a dialog to confirm password change
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade50,
        title: Text(
          'Change Password',
          style: TextStyle(
            color: Colors.amber.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: Colors.grey.shade700),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber.shade800),
                ),
                fillColor: Colors.grey.shade50,
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Update password in the database
                if (apiculteurId.isNotEmpty) {
                  await _database.child('apiculteurs/$apiculteurId').update({
                    'pwd': pwdController.text,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Password updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating password: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerApiculteur() async {
    try {
      // Create Firebase auth account
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: userData['email'],
        password: userData['pwd'],
      );

      if (userCredential.user != null) {
        // Mark as registered in our local state regardless of email
        setState(() {
          userData['isRegistered'] = true;
        });

        // Show success message only if it's not test email
        if (userData['email'] != 'test@gmail.com') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Apiculteur registered successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Test account registered successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error registering apiculteur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.amber.shade100,
                Colors.amber.shade50,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCurrentUser ? 'My Profile' : 'View Profile',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: Icon(
                isEditing ? Icons.save : Icons.edit,
                color: Colors.amber.shade800,
              ),
              onPressed: toggleEditMode,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.amber.shade100,
              Colors.amber.shade50,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Registration status badge
                if (!isLoading)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Registered',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                // Profile picture
                Center(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.amber.shade800,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade50,
                          child: Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                      if (isEditing && isCurrentUser)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Photo upload feature not implemented'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Apiculteur information
                ProfileField(
                  icon: Icons.person,
                  title: 'Login',
                  value: userData['login'],
                  controller: loginController,
                  isEditing: isEditing && isCurrentUser,
                ),

                const SizedBox(height: 16),
                ProfileField(
                  icon: Icons.badge,
                  title: 'Nom',
                  value: userData['nom'],
                  controller: nomController,
                  isEditing: isEditing && isCurrentUser,
                ),

                const SizedBox(height: 16),
                ProfileField(
                  icon: Icons.person_outline,
                  title: 'Prénom',
                  value: userData['prenom'],
                  controller: prenomController,
                  isEditing: isEditing && isCurrentUser,
                ),

                const SizedBox(height: 16),
                ProfileField(
                  icon: Icons.email,
                  title: 'Email',
                  value: userData['email'],
                  controller: emailController,
                  isEditing: isEditing && isCurrentUser,
                ),

                const SizedBox(height: 16),
                ProfileField(
                  icon: Icons.location_on,
                  title: 'Address',
                  value: userData['address'],
                  controller: addressController,
                  isEditing: isEditing && isCurrentUser,
                ),

                const SizedBox(height: 16),
                ProfileField(
                  icon: Icons.password,
                  title: 'Password',
                  value: '••••••••', // Masked password
                  controller: pwdController,
                  isEditing: isEditing && isCurrentUser,
                  isPassword: true,
                ),

                const SizedBox(height: 16),
                ProfileField(
                  icon: Icons.calendar_today,
                  title: 'Joined',
                  value: userData['joinedDate'],
                  isEditable: false, // Join date cannot be edited
                ),

                const SizedBox(height: 32),
                if (!isEditing && isCurrentUser)
                  ElevatedButton(
                    onPressed: _changePassword,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Change Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                // Registration button for non-registered apiculteurs
                if (!userData['isRegistered'] && !isCurrentUser)
                  ElevatedButton(
                    onPressed: _registerApiculteur,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Register This Apiculteur',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileField extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final TextEditingController? controller;
  final bool isEditing;
  final bool isEditable;
  final bool isPassword;

  const ProfileField({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    this.controller,
    this.isEditing = false,
    this.isEditable = true,
    this.isPassword = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.amber.shade800,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (isEditing && isEditable)
                  TextField(
                    controller: controller,
                    obscureText: isPassword,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.amber.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.amber.shade800, width: 2),
                      ),
                      fillColor: Colors.grey.shade50,
                      filled: true,
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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