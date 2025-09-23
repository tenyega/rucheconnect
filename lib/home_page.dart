
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'view_profile.dart';
import 'package:tp_flutter/ruchers.dart';
import 'package:tp_flutter/ruche.dart' as ruche;// Import the new ruche.dart file
import 'package:tp_flutter/contactUs.dart';

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
  List<Apiculteur> _apiculteurs = [];

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
      if (email == 'mdolma@ymail.com') {
        setState(() {
          _userRole = UserRole.admin;
          _isLoading = false;
        });
      } else {
        // Check if the email exists in the apiculteurs database
        try {
          final DatabaseReference apiculteursRef = FirebaseDatabase.instance.ref('apiculteurs');
          final snapshot = await apiculteursRef.get();

          bool isApiculteur = false;

          if (snapshot.exists && snapshot.value != null) {
            final Map<dynamic, dynamic> apiculteurs = snapshot.value as Map<dynamic, dynamic>;

            // Check if any apiculteur has this email
            for (var apiculteurData in apiculteurs.values) {
              if (apiculteurData is Map && apiculteurData['email'] == email) {
                isApiculteur = true;
                break;
              }
            }
          }

          if (isApiculteur) {
            setState(() {
              _userRole = UserRole.apiculteur;
              _currentIndex = 0; // Reset to first apiculteur page (Rucher)
              _isLoading = false;
            });
          } else {
            // Email not found in apiculteurs - set to unknown role
            setState(() {
              _userRole = UserRole.unknown;
              _isLoading = false;
            });
          }
        } catch (e) {
          // Error accessing database - set to unknown role
          setState(() {
            _userRole = UserRole.unknown;
            _isLoading = false;
          });
        }
      }
    } else {
      // No current user - set to unknown role
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
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }

    // If user role is unknown, show an error message
    if (_userRole == UserRole.unknown) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Accès Refusé'),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Accès non autorisé',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous n\'avez pas les droits nécessaires pour accéder à cette application.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
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
        ? [
      const BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Apiculteurs',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.hive),
        label: 'Rucher',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bug_report),
        label: 'Ruche',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.logout),
        label: 'Logout',
      ),
    ]
        : [
      const BottomNavigationBarItem(
        icon: Icon(Icons.hive),
        label: 'Rucher',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bug_report),
        label: 'Ruche',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.logout),
        label: 'Logout',
      ),
    ];

    // Display the appropriate UI based on user role
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
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
        backgroundColor: Colors.white,
        selectedItemColor: Colors.amber.shade800,
        unselectedItemColor: Colors.grey.shade600,
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
  List<RucherInfo> ruchers; // <-- Add this line

  Apiculteur({
    required this.id,
    required this.address,
    required this.email,
    required this.login,
    required this.nom,
    required this.prenom,
    required this.pwd,
    this.isExpanded = false,
    this.ruchers = const [], // <-- Add this too (with default empty list)
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
          SnackBar(
            content: const Text('Liste des apiculteurs actualisée'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'actualisation: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
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

  bool _hasActiveAlert(RucheInfo ruche) {
    // Use the new hasActiveAlert getter from RucheInfo
    return ruche.hasActiveAlert;
  }

  int _getTotalActiveAlerts() {
    int totalAlerts = 0;
    for (var apiculteur in _apiculteurs) {
      for (var rucher in apiculteur.ruchers) {
        for (var ruche in rucher.ruches) {
          if (_hasActiveAlert(ruche)) {
            totalAlerts++;
          }
        }
      }
    }
    return 1;
  }

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
    final snapshot = await _apiculteursRef.get();
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      List<Apiculteur> loadedApiculteurs = [];

      for (var entry in data.entries) {
        final key = entry.key.toString();
        final apiculteurMap = Map<String, dynamic>.from(entry.value);
        List<RucherInfo> ruchers = [];

        // Loop through all keys in apiculteur map to find ruchers
        for (var subEntry in apiculteurMap.entries) {
          if (subEntry.key.toString().startsWith('rucher_')) {
            final rucherMap = Map<String, dynamic>.from(subEntry.value);
            List<RucheInfo> ruches = [];

            for (var rucheEntry in rucherMap.entries) {
              if (rucheEntry.key.toString().startsWith('ruche_')) {
                final rucheDataMap = Map<String, dynamic>.from(rucheEntry.value);
                final latest = rucheDataMap.entries.last.value.toString().split('/');
                int? alert = int.tryParse(latest.last);
                ruchers.add(RucherInfo(
                  id: subEntry.key.toString(),
                  address: '',
                  description: '',
                  picUrl: '',
                  rucheCount: ruches.length,
                  ruches: ruches,
                ));
              }
            }

            ruchers.add(RucherInfo(
              id: subEntry.key.toString(),
              address: '',
              description: '',
              picUrl: '',
              rucheCount: ruches.length,
              ruches: ruches,
            ));
          }
        }

        loadedApiculteurs.add(Apiculteur(
          id: key,
          login: apiculteurMap['login'] ?? '',
          email: apiculteurMap['email'] ?? '',
          nom: apiculteurMap['nom'] ?? '',
          prenom: apiculteurMap['prenom'] ?? '',
          address: apiculteurMap['address'] ?? '',
          pwd: apiculteurMap['pwd']?.toString() ?? '',
          ruchers: ruchers,
        ));
      }

      setState(() {
        _apiculteurs = loadedApiculteurs;
      });
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
          SnackBar(
            content: const Text('Liste des apiculteurs actualisée'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'actualisation: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
        backgroundColor: Colors.white,
        title: Text(
          'Ajouter un apiculteur',
          style: TextStyle(color: Colors.amber.shade800),
        ),
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.amber.shade100, Colors.amber.shade50],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStyledTextField(loginController, 'Login'),
                const SizedBox(height: 12),
                _buildStyledTextField(emailController, 'Email',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildStyledTextField(nomController, 'Nom'),
                const SizedBox(height: 12),
                _buildStyledTextField(prenomController, 'Prénom'),
                const SizedBox(height: 12),
                _buildStyledTextField(addressController, 'Adresse'),
                const SizedBox(height: 12),
                _buildStyledTextField(pwdController, 'Mot de passe',
                    obscureText: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
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
          SnackBar(
            content: const Text('Apiculteur ajouté avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildStyledTextField(TextEditingController controller, String label,
      {TextInputType? keyboardType, bool obscureText = false}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.amber.shade800),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.amber.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.amber.shade800, width: 2),
        ),
      ),
    );
  }

  Future<void> _deleteApiculteur(String apiId) async {
    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Confirmer la suppression',
          style: TextStyle(color: Colors.amber.shade800),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer $apiId ?',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiculteursRef.child(apiId).remove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$apiId supprimé'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
        backgroundColor: Colors.white,
        title: Text(
          'Modifier $field',
          style: TextStyle(color: Colors.amber.shade800),
        ),
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.amber.shade100, Colors.amber.shade50],
            ),
          ),
          child: _buildStyledTextField(controller, field, obscureText: isPassword),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue != currentValue) {
      try {
        await _apiculteursRef.child('$apiId/$field').set(newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$field mis à jour'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.amber.shade100, Colors.amber.shade50],
            ),
          ),
          child: Column(
            children: [
              // Alert banner
              if (_getTotalActiveAlerts() > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '⚠️ ${_getTotalActiveAlerts()} ruche(s) en alerte - Vol de miel détecté!',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Apiculteurs list
              Expanded(
                child: ListView.builder(
                  itemCount: _apiculteurs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _apiculteurs.length) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.add, color: Colors.amber.shade800),
                          title: Text(
                            'Ajouter un apiculteur',
                            style: TextStyle(color: Colors.amber.shade800),
                          ),
                          onTap: _addApiculteur,
                        ),
                      );
                    }

                    final apiculteur = _apiculteurs[index];
                    return _buildApiculteurItem(apiculteur);
                  },
                ),
              ),
            ],
          ),
        ),

        // Overlay loading spinner
        if (_isRefreshing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildApiculteurItem(Apiculteur apiculteur) {
    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: ExpansionTile(
    title: Row(
    children: [
    Expanded(
    child: Text(
    apiculteur.id,
    style: TextStyle(
    color: Colors.amber.shade800,
    fontWeight: FontWeight.bold,
    ),
    ),
    ),
    IconButton(
    icon: const Icon(Icons.delete),
    color: Colors.red,
    onPressed: () => _deleteApiculteur(apiculteur.id),
    tooltip: 'Supprimer',
    ),
    ],
    ),
    leading: Icon(
    Icons.arrow_drop_down,
    color: Colors.amber.shade800,
    ),
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
    )
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
            child: Text('$label:', style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade800, // Header text color
            )),
          ),
          Expanded(
            flex: 2,
            child: Text(displayValue, style: TextStyle(
              color: Colors.grey.shade700, // Secondary text color
            )),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 20, color: Colors.amber.shade800), // Icon color
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.amber.shade100, // Gradient start
            Colors.amber.shade50,  // Gradient end
          ],
        ),
      ),
      child: FutureBuilder<Map<dynamic, dynamic>?>(
          future: _getCurrentApiculteur(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Loading indicator color
                ),
              );
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
                      color: Colors.white, // Card background
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.amber.shade100, // Avatar background
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.amber.shade800, // Avatar icon color
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${apiculteur['prenom']} ${apiculteur['nom']}",
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.amber.shade800, // Header text color
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    apiculteur['email'] ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade700, // Secondary text color
                                    ),
                                  ),
                                  Text(
                                    "ID: ${apiculteur['id']}",
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade700, // Secondary text color
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Profile menu items
                  Card(
                    color: Colors.white, // Card background
                    elevation: 1,
                    child: ListTile(
                      leading: Icon(Icons.person, color: Colors.amber.shade800), // Icon color
                      title: Text('View Profile', style: TextStyle(
                        color: Colors.black, // Text color
                        fontWeight: FontWeight.w500,
                      )),
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
                  ),
                  const SizedBox(height: 8),

                  Card(
                    color: Colors.white, // Card background
                    elevation: 1,
                    child: ListTile(
                      leading: Icon(Icons.password, color: Colors.amber.shade800), // Icon color
                      title: Text('Change Password', style: TextStyle(
                        color: Colors.black, // Text color
                        fontWeight: FontWeight.w500,
                      )),
                      onTap: () async {
                        // Show password change dialog - using a simple implementation for demo
                        final TextEditingController pwdController = TextEditingController();

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white, // Dialog background
                            title: Text('Change Password', style: TextStyle(
                              color: Colors.amber.shade800, // Header text color
                              fontWeight: FontWeight.bold,
                            )),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: pwdController,
                                  obscureText: true,
                                  style: TextStyle(color: Colors.black), // Input text color
                                  decoration: InputDecoration(
                                    labelText: 'New Password',
                                    labelStyle: TextStyle(color: Colors.grey.shade700), // Label color
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.amber.shade800),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.amber.shade800, width: 2),
                                    ),
                                    fillColor: Colors.grey.shade50, // Fill color
                                    filled: true,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel', style: TextStyle(
                                  color: Colors.grey.shade700, // Cancel button color
                                )),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber, // Submit button background
                                  foregroundColor: Colors.black, // Submit button text
                                ),
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
                                          SnackBar(
                                            content: Text('Password updated successfully'),
                                            backgroundColor: Colors.green, // Success message background
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error updating password: $e'),
                                          backgroundColor: Colors.red, // Error message background
                                        ),
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
                  ),
                  const SizedBox(height: 8),

                  Card(
                    color: Colors.white, // Card background
                    elevation: 1,
                    child: ListTile(
                      leading: Icon(Icons.mail, color: Colors.amber.shade800), // Icon color
                      title: Text('Contact Us', style: TextStyle(
                        color: Colors.black, // Text color
                        fontWeight: FontWeight.w500,
                      )),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ContactPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}

// Placeholder for logout screen
class LogoutContent extends StatelessWidget {
  const LogoutContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.amber.shade100, // Gradient start
            Colors.amber.shade50,  // Gradient end
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Loading indicator color
            ),
            const SizedBox(height: 16),
            Text(
              'Logging out...',
              style: TextStyle(
                color: Colors.amber.shade800, // Text color
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RucheContent extends StatelessWidget {
  const RucheContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ruche.RucherRucheViewState();
  }
}