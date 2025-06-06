import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'view_profile.dart';

class ApiculteurListPage extends StatefulWidget {
  const ApiculteurListPage({Key? key}) : super(key: key);

  @override
  State<ApiculteurListPage> createState() => _ApiculteurListPageState();
}

class _ApiculteurListPageState extends State<ApiculteurListPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> apiculteurs = [];
  bool isLoading = true;

  @override
  void initState() {
    print('=== DEBUG: initState called ===');
    super.initState();

    // Add a small delay to ensure the widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('=== DEBUG: PostFrameCallback - About to call _loadApiculteurs ===');
      _loadApiculteurs();
      print('=== DEBUG: PostFrameCallback - _loadApiculteurs call finished ===');
    });
  }

  Future<void> _loadApiculteurs() async {
    print('=== DEBUG: _loadApiculteurs() function called ===');
    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final apiculteursRef = _database.child('apiculteurs');
      final snapshot = await apiculteursRef.get();

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> loadedApiculteurs = [];

        data.forEach((key, value) {
          if (value is Map && key.toString().startsWith('api_')) {
            final apiculteur = Map<String, dynamic>.from(value);
            apiculteur['id'] = key;
            loadedApiculteurs.add(apiculteur);
          }
        });

        loadedApiculteurs.sort((a, b) {
          final aMatch = RegExp(r'api_0*(\d+)').firstMatch(a['id']);
          final bMatch = RegExp(r'api_0*(\d+)').firstMatch(b['id']);
          if (aMatch != null && bMatch != null) {
            return int.parse(aMatch.group(1)!).compareTo(int.parse(bMatch.group(1)!));
          }
          return a['id'].compareTo(b['id']);
        });

        if (mounted) {
          setState(() {
            apiculteurs = loadedApiculteurs;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            apiculteurs = [];
            isLoading = false;
          });
        }
      }
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading apiculteurs: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  // Function to check if a user is registered
  Future<bool> _isRegistered(String email) async {
    print('=== DEBUG: Checking registration for email: $email ===');
    try {
      final result = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      print('=== DEBUG: Registration check result for $email: ${result.isNotEmpty} ===');
      return result.isNotEmpty;
    } catch (e) {
      print('=== DEBUG: Error checking registration for $email: $e ===');
      return false;
    }
  }

  Future<void> _addApiculteur() async {
    print('=== DEBUG: _addApiculteur called ===');
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
      print('=== DEBUG: Dialog result received, processing new apiculteur ===');
      try {
        // Generate a new apiX ID where X is a number
        int maxApiNumber = 0;

        // First, get all existing API IDs from Firebase to ensure we don't have duplicates
        print('=== DEBUG: Getting existing API IDs ===');
        final allApiculteursSnapshot = await _database.child('apiculteurs').get();
        if (allApiculteursSnapshot.exists) {
          final allData = allApiculteursSnapshot.value as Map<dynamic, dynamic>;
          allData.forEach((key, value) {
            if (key.toString().startsWith('api_')) {
              //final match = RegExp(r'api_(\d+)').firstMatch(key.toString());
              final match = RegExp(r'^api_(\d{3})$').firstMatch(key.toString());

              if (match != null) {
                final number = int.parse(match.group(1)!);
                if (number > maxApiNumber) {
                  maxApiNumber = number;
                }
              }
            }
          });
        }

        final newApiId = 'api_${(maxApiNumber + 1).toString().padLeft(3, '0')}';

        print('=== DEBUG: Generated new API ID: $newApiId ===');

        await _database.child('apiculteurs').child(newApiId).set({
          'login': result['login'],
          'email': result['email'],
          'nom': result['nom'],
          'prenom': result['prenom'],
          'address': result['address'],
          'pwd': result['pwd'],
          'joinedDate': DateTime.now().toString().substring(0, 10), // Add join date
        });

        print('=== DEBUG: New apiculteur saved successfully ===');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Apiculteur ajouté avec succès')),
          );
        }

        // Refresh the list
        print('=== DEBUG: Refreshing list after adding new apiculteur ===');
        _loadApiculteurs();
      } catch (e) {
        print('=== DEBUG: Error adding apiculteur: $e ===');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}')),
          );
        }
      }
    } else {
      print('=== DEBUG: Dialog was cancelled ===');
    }
  }

  Future<void> _registerApiculteur(String email, String password, String apiId) async {
    print('=== DEBUG: Registering apiculteur: $email, ID: $apiId ===');
    try {
      // Create Firebase auth account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('=== DEBUG: Firebase auth account created successfully ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apiculteur enregistré avec succès')),
        );
      }

      // Refresh to update registration status
      _loadApiculteurs();
    } catch (e) {
      print('=== DEBUG: Error registering apiculteur: $e ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'enregistrement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('=== DEBUG: build() called, isLoading: $isLoading, apiculteurs count: ${apiculteurs.length} ===');

    if (isLoading) {
      print('=== DEBUG: Showing loading indicator ===');
      return const Center(child: CircularProgressIndicator());
    }

    if (apiculteurs.isEmpty) {
      print('=== DEBUG: Showing empty state ===');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Aucun apiculteur trouvé'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addApiculteur,
              child: const Text('Ajouter un apiculteur'),
            ),
          ],
        ),
      );
    }

    print('=== DEBUG: Building list with ${apiculteurs.length} apiculteurs ===');
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadApiculteurs,
        child: ListView.builder(
          itemCount: apiculteurs.length,
          itemBuilder: (context, index) {
            final apiculteur = apiculteurs[index];
            print('=== DEBUG: Building list item $index: ${apiculteur['prenom']} ${apiculteur['nom']} ===');

            return FutureBuilder<bool>(
              future: _isRegistered(apiculteur['email']),
              builder: (context, snapshot) {
                final isRegistered = snapshot.data ?? false;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColorLight,
                      child: Text(
                        (apiculteur['prenom'] as String).isNotEmpty
                            ? (apiculteur['prenom'] as String)[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('${apiculteur['prenom']} ${apiculteur['nom']}'),
                    subtitle: Text(apiculteur['email']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRegistered ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isRegistered ? 'Enregistré' : 'Non Enregistré',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        if (!isRegistered)
                          IconButton(
                            icon: const Icon(Icons.app_registration, color: Colors.blue),
                            onPressed: () => _registerApiculteur(
                                apiculteur['email'],
                                apiculteur['pwd'] ?? '123456', // Default password if none exists
                                apiculteur['id']
                            ),
                            tooltip: 'Enregistrer',
                          ),
                      ],
                    ),
                    onTap: () {
                      print('=== DEBUG: Navigating to profile for ${apiculteur['id']} ===');
                      // Navigate to the apiculteur's profile
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewProfilePage(
                            apiculteurId: apiculteur['id'],
                          ),
                        ),
                      ).then((_) => _loadApiculteurs()); // Refresh on return
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addApiculteur,
        child: const Icon(Icons.add),
        tooltip: 'Ajouter un apiculteur',
      ),
    );
  }
}