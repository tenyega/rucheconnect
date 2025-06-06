
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tp_flutter/ruchers.dart';
import 'package:tp_flutter/ruche.dart'; // Import the new ruche.dart file
import 'view_profile.dart';

// Define a UserRole enum for better type safety
enum UserRole {
  admin,
  apiculteur,
  unknown
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  UserRole _userRole = UserRole.unknown;
  bool _isLoading = true;

  // Late variables for the pages and navigation items
  late final List<Widget> _currentPages;
  late final List<BottomNavigationBarItem> _currentNavItems;

  @override
  void initState() {
    super.initState();
    // Check the user role
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && currentUser.email != null) {
      final String email = currentUser.email!;

      // Check if the user is an admin (email is test@gmail.com)
      if (email == 'test@gmail.com') {
        setState(() {
          _userRole = UserRole.admin;
          _isLoading = false;
        });
      }
      // Check if the user is an apiculteur (email starts with api and ends with @email.com)
      else if (email.startsWith('api') && email.endsWith('@email.com')) {
        setState(() {
          _userRole = UserRole.apiculteur;
          _currentIndex = 0; // Reset to first apiculteur page (Rucher)
          _isLoading = false;
        });
      }
      else {
        // If not admin or apiculteur, set to unknown role
        setState(() {
          _userRole = UserRole.unknown;
          _isLoading = false;
        });
      }
    } else {
      // User not authenticated
      setState(() {
        _userRole = UserRole.unknown;
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (_userRole == UserRole.admin) {
      // For admin
      if (index == 4) {
        // Handle logout separately
        _logout();
      } else {
        setState(() {
          _currentIndex = index;
        });
      }
    } else if (_userRole == UserRole.apiculteur) {
      // For apiculteur - they have fewer items
      if (index == 3) {
        // Handle logout separately for apiculteur (logout is at index 3)
        _logout();
      } else {
        setState(() {
          _currentIndex = index;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    // No need for explicit navigation
    // The AuthGate StreamBuilder in main.dart will automatically
    // detect the sign-out and show the LoginPage
  }

  String _getAppBarTitle() {
    if (_userRole == UserRole.admin) {
      return _currentIndex == 0
          ? 'Apiculteurs'
          : _currentIndex == 1
          ? ' '
          : _currentIndex == 2
          ? ' '
          : _currentIndex == 3
          ? 'Profile'
          : 'Logout';
    } else { // For apiculteur
      return _currentIndex == 0
          ? ' '
          : _currentIndex == 1
          ? ' '
          : _currentIndex == 2
          ? 'Profile'
          : 'Logout';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If user role is unknown, show an error message
    if (_userRole == UserRole.unknown) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Accès Refusé'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Accès non autorisé',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vous n\'avez pas les droits nécessaires pour accéder à cette application.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _logout,
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      );
    }

    // Define pages and navigation items based on user role
    final List<Widget> pages = _userRole == UserRole.admin
        ? [
      const ApiculteursContent(),
      const RucherListContent(), // From ruchers.dart
      const RucheContent(), // From ruche.dart
      const ProfileContent(),
      const LogoutContent(),
    ]
        : [
      const RucherListContent(), // Apiculteur starts with Rucher page
      const RucheContent(),
      const ProfileContent(),
      const LogoutContent(),
    ];

    final List<BottomNavigationBarItem> navItems = _userRole == UserRole.admin
        ? const [
      BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Apiculteurs',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.hive),
        label: 'Rucher',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.bug_report),
        label: 'Ruche',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.logout),
        label: 'Logout',
      ),
    ]
        : const [
      BottomNavigationBarItem(
        icon: Icon(Icons.hive),
        label: 'Rucher',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.bug_report),
        label: 'Ruche',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.logout),
        label: 'Logout',
      ),
    ];

    // Display the appropriate UI based on user role
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        // Add the refresh button to the AppBar when admin is on the Apiculteurs page
        actions: _userRole == UserRole.admin && _currentIndex == 0
            ? [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Use the static method to refresh
              ApiculteursContent.refresh(context);
            },
            tooltip: 'Actualiser la liste',
          ),
        ]
            : null,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }
}

// Model class for Apiculteur
class Apiculteur {
  String id;
  String address;
  String email;
  String login;
  String nom;
  String prenom;
  String pwd;
  bool isExpanded;

  Apiculteur({
    required this.id,
    required this.address,
    required this.email,
    required this.login,
    required this.nom,
    required this.prenom,
    required this.pwd,
    this.isExpanded = false,
  });
}

// Updated content widget for the Apiculteurs page
class ApiculteursContent extends StatefulWidget {
  const ApiculteursContent({Key? key}) : super(key: key);

  @override
  State<ApiculteursContent> createState() => _ApiculteursContentState();

  // Static method to refresh that can be called from outside
  static void refresh(BuildContext context) {
    // Access the state through the current context
    final DatabaseReference apiculteursRef = FirebaseDatabase.instance.ref('apiculteurs');
    apiculteursRef.get().then((snapshot) {
      if (snapshot.exists && snapshot.value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste des apiculteurs actualisée')),
        );
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'actualisation: $error')),
      );
    });
  }
}

class _ApiculteursContentState extends State<ApiculteursContent> {
  final DatabaseReference _apiculteursRef = FirebaseDatabase.instance.ref('apiculteurs');
  List<Apiculteur> _apiculteurs = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadApiculteurs();

    // Set up listener for real-time updates
    _apiculteursRef.onValue.listen((event) {
      _loadApiculteursFromSnapshot(event.snapshot);
    });
  }

  Future<void> _loadApiculteurs() async {
    print('=== DEBUG: _loadApiculteurs() function called ===');
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final snapshot = await _apiculteursRef.get();

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Apiculteur> loadedApiculteurs = [];

        data.forEach((key, value) {
          if (value is Map && key.toString().startsWith('api_')) {
            final apiculteurMap = Map<String, dynamic>.from(value);
            final apiculteur = Apiculteur(
              id: key.toString(),
              login: apiculteurMap['login'] ?? '',
              email: apiculteurMap['email'] ?? '',
              nom: apiculteurMap['nom'] ?? '',
              prenom: apiculteurMap['prenom'] ?? '',
              address: apiculteurMap['address'] ?? '',
              pwd: apiculteurMap['pwd']?.toString() ?? '',
            );
            loadedApiculteurs.add(apiculteur);
          }
        });


        if (mounted) {
          setState(() {
            _apiculteurs = loadedApiculteurs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _apiculteurs = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading apiculteurs: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Fixed refresh method to ensure message is shown
  Future<void> _refreshApiculteurs() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final snapshot = await _apiculteursRef.get();
      _loadApiculteursFromSnapshot(snapshot);

      // Show confirmation of refresh - Made sure this message appears
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste des apiculteurs actualisée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'actualisation: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _loadApiculteursFromSnapshot(DataSnapshot snapshot) {
    setState(() {
      _apiculteurs = [];

      if (snapshot.exists && snapshot.value != null) {
        final map = snapshot.value as Map<dynamic, dynamic>;

        map.forEach((key, value) {
          if (key.toString().startsWith('api')) {
            _apiculteurs.add(Apiculteur(
              id: key.toString(),
              address: (value as Map<dynamic, dynamic>)['address'] ?? '',
              email: value['email'] ?? '',
              login: value['login'] ?? '',
              nom: value['nom'] ?? '',
              prenom: value['prenom'] ?? '',
              pwd: value['pwd']?.toString() ?? '',
            ));
          }
        });

        // ✅ Sort here by numeric value of api_X ID
        _apiculteurs.sort((a, b) {
          final aMatch = RegExp(r'api_0*(\d+)').firstMatch(a.id);
          final bMatch = RegExp(r'api_0*(\d+)').firstMatch(b.id);
          if (aMatch != null && bMatch != null) {
            return int.parse(aMatch.group(1)!).compareTo(int.parse(bMatch.group(1)!));
          }
          return a.id.compareTo(b.id);
        });
      }

      _isLoading = false;
    });
  }


  Future<void> _addApiculteur() async {
    // Show dialog to collect apiculteur data
    final TextEditingController loginController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nomController = TextEditingController();
    final TextEditingController prenomController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController pwdController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un apiculteur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: loginController,
                decoration: const InputDecoration(labelText: 'Login'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: prenomController,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
              TextField(
                controller: pwdController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop({
                'login': loginController.text,
                'email': emailController.text,
                'nom': nomController.text,
                'prenom': prenomController.text,
                'address': addressController.text,
                'pwd': pwdController.text,
              });
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Generate a new apiX ID where X is a number
        final apiCount = _apiculteurs.length + 1;
        final newApiId = 'api_00$apiCount';

        await _apiculteursRef.child(newApiId).set({
          'login': result['login'],
          'email': result['email'],
          'nom': result['nom'],
          'prenom': result['prenom'],
          'address': result['address'],
          'pwd': result['pwd'],
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apiculteur ajouté avec succès')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteApiculteur(String apiId) async {
    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer $apiId ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiculteursRef.child(apiId).remove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$apiId supprimé')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _editApiculteurField(String apiId, String field, String currentValue) async {
    // Show dialog to edit field
    final TextEditingController controller = TextEditingController(text: currentValue);
    final bool isPassword = field == 'pwd';

    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: field),
          obscureText: isPassword,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue != currentValue) {
      try {
        await _apiculteursRef.child('$apiId/$field').set(newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$field mis à jour')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Scaffold(
          body: ListView.builder(
            itemCount: _apiculteurs.length + 1, // +1 for the add button
            itemBuilder: (context, index) {
              if (index == _apiculteurs.length) {
                // Last item is an add button
                return ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Ajouter un apiculteur'),
                  onTap: _addApiculteur,
                );
              }

              final apiculteur = _apiculteurs[index];
              return _buildApiculteurItem(apiculteur);
            },
          ),
          // Removed the floating action button
        ),
        // Show overlay loading indicator when refreshing
        if (_isRefreshing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildApiculteurItem(Apiculteur apiculteur) {
    return ExpansionTile(
      title: Row(
        children: [
          Expanded(child: Text(apiculteur.id)),

          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteApiculteur(apiculteur.id),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      leading: const Icon(Icons.arrow_drop_down),
      initiallyExpanded: apiculteur.isExpanded,
      onExpansionChanged: (expanded) {
        setState(() {
          apiculteur.isExpanded = expanded;
        });
      },
      children: [
        // Apiculteur details
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEditableRow('Login', apiculteur.login,
                      () => _editApiculteurField(apiculteur.id, 'login', apiculteur.login)),
              _buildEditableRow('Email', apiculteur.email,
                      () => _editApiculteurField(apiculteur.id, 'email', apiculteur.email)),
              _buildEditableRow('Nom', apiculteur.nom,
                      () => _editApiculteurField(apiculteur.id, 'nom', apiculteur.nom)),
              _buildEditableRow('Prénom', apiculteur.prenom,
                      () => _editApiculteurField(apiculteur.id, 'prenom', apiculteur.prenom)),
              _buildEditableRow('Adresse', apiculteur.address,
                      () => _editApiculteurField(apiculteur.id, 'address', apiculteur.address)),
              _buildEditableRow('Mot de passe', apiculteur.pwd,
                      () => _editApiculteurField(apiculteur.id, 'pwd', apiculteur.pwd)),
              const SizedBox(height: 16),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableRow(String label, String value, VoidCallback onEdit) {
    // Mask the password with asterisks if the label is for password
    String displayValue = label == 'Mot de passe' ? '••••••••' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(displayValue),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: onEdit,
            tooltip: 'Modifier',
          ),
        ],
      ),
    );
  }
}

class ProfileContent extends StatelessWidget {
  const ProfileContent({Key? key}) : super(key: key);

  Future<Map<dynamic, dynamic>?> _getCurrentApiculteur() async {
    try {
      // Get current user's email
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        return null;
      }

      // Search for apiculteur with matching email
      final String email = currentUser.email!;
      final DatabaseReference apiculteursRef = FirebaseDatabase.instance.ref('apiculteurs');
      final snapshot = await apiculteursRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> apiculteurs = snapshot.value as Map<dynamic, dynamic>;

        // Find apiculteur with matching email
        String? apiculteurId;
        Map<dynamic, dynamic>? apiculteurData;

        apiculteurs.forEach((key, value) {
          if (value is Map && value['email'] == email) {
            apiculteurId = key.toString();
            apiculteurData = {...value as Map<dynamic, dynamic>, 'id': key.toString()};
          }
        });

        return apiculteurData;
      }
    } catch (e) {
      debugPrint('Error fetching apiculteur data: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<dynamic, dynamic>?>(
        future: _getCurrentApiculteur(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final apiculteur = snapshot.data;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show current apiculteur info at the top
                if (apiculteur != null)
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${apiculteur['prenom']} ${apiculteur['nom']}",
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  apiculteur['email'] ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  "ID: ${apiculteur['id']}",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Profile menu items
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('View Profile'),
                  onTap: () {
                    // Navigate to the ViewProfilePage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ViewProfilePage(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Change Password'),
                  onTap: () async {
                    // Show password change dialog - using a simple implementation for demo
                    final TextEditingController pwdController = TextEditingController();

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
                                final apiculteurData = await _getCurrentApiculteur();
                                if (apiculteurData != null && apiculteurData['id'] != null) {
                                  // Update password in the database
                                  await FirebaseDatabase.instance
                                      .ref('apiculteurs/${apiculteurData['id']}')
                                      .update({'pwd': pwdController.text});

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Password updated successfully')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error updating password: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }
    );
  }
}

// Placeholder for logout screen
class LogoutContent extends StatelessWidget {
  const LogoutContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Logging out...'),
    );
  }
}

class RucheContent extends StatelessWidget {
  const RucheContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This redirects to your new implementation
    return const RucherRucheViewState();
  }
}