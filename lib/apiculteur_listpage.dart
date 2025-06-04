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
    super.initState();
    _loadApiculteurs();
  }

  Future<void> _loadApiculteurs() async {
    try {
      setState(() {
        isLoading = true;
      });

      final apiculteursRef = _database.child('apiculteurs');
      final snapshot = await apiculteursRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> loadedApiculteurs = [];

        data.forEach((key, value) {
          if (value is Map && key.toString().startsWith('api')) {
            final apiculteur = Map<String, dynamic>.from(value as Map);
            apiculteur['id'] = key;
            loadedApiculteurs.add(apiculteur);
          }
        });

        setState(() {
          apiculteurs = loadedApiculteurs;
          isLoading = false;
        });
      } else {
        setState(() {
          apiculteurs = [];
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading apiculteurs: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to check if a user is registered
  Future<bool> _isRegistered(String email) async {
    try {
      final result = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
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
        final apiCount = apiculteurs.length + 1;
        final newApiId = 'api$apiCount';

        await _database.child('apiculteurs').child(newApiId).set({
          'login': result['login'],
          'email': result['email'],
          'nom': result['nom'],
          'prenom': result['prenom'],
          'address': result['address'],
          'pwd': result['pwd'],
          'joinedDate': DateTime.now().toString().substring(0, 10), // Add join date
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apiculteur ajouté avec succès')),
        );

        // Refresh the list
        _loadApiculteurs();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _registerApiculteur(String email, String password, String apiId) async {
    try {
      // Create Firebase auth account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apiculteur enregistré avec succès')),
      );

      // Refresh to update registration status
      _loadApiculteurs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'enregistrement: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (apiculteurs.isEmpty) {
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadApiculteurs,
        child: ListView.builder(
          itemCount: apiculteurs.length,
          itemBuilder: (context, index) {
            final apiculteur = apiculteurs[index];
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