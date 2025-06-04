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
          const SnackBar(content: Text('No authenticated user found')),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apiculteur not found for this account')),
        );
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
          const SnackBar(content: Text('Apiculteur not found')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading apiculteur: $e')),
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
        const SnackBar(content: Text('You can only edit your own profile')),
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
          const SnackBar(content: Text('No apiculteur ID found to update')),
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
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> _changePassword() async {
    // Show a dialog to confirm password change
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Update password in the database
                if (apiculteurId.isNotEmpty) {
                  await _database.child('apiculteurs/$apiculteurId').update({
                    'pwd': pwdController.text,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating password: $e')),
                );
              }
            },
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
        // Mark as registered in our local state
        setState(() {
          userData['isRegistered'] = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apiculteur registered successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering apiculteur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUser ? 'My Profile' : 'View Profile'),
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: Icon(isEditing ? Icons.save : Icons.edit),
              onPressed: toggleEditMode,
            ),
        ],
      ),
      body: SingleChildScrollView(
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
                      color: userData['isRegistered'] ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userData['isRegistered'] ? 'Registered' : 'Not Registered',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

              // Profile picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      child: const Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                    if (isEditing && isCurrentUser)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Photo upload feature not implemented')),
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
                  ),
                  child: const Text('Change Password'),
                ),

              // Registration button for non-registered apiculteurs
              if (!userData['isRegistered'] && !isCurrentUser)
                ElevatedButton(
                  onPressed: _registerApiculteur,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Register This Apiculteur'),
                ),
            ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
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
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
      ],
    );
  }
}