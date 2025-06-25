# 🐝 Ruche Connectée – Application Flutter

Surveillance intelligente de ruches via capteurs IoT, Firebase et application mobile Flutter.

## 📱 Fonctionnalités principales

- Authentification sécurisée via **Firebase Auth**
- Gestion complète des ruchers et ruches par l’apiculteur
- Visualisation des mesures (🌡️ Température / 💧 Humidité)
- Alerte en cas d’ouverture non autorisée du couvercle
- Désactivation manuelle de l’alerte pendant visite
- Graphiques hebdomadaires des données
- Administration CRUD des apiculteurs (rôle admin)

## 🧑‍💻 Technologies utilisées

| Composant | Stack |
|----------|-------|
| App Mobile | `Flutter 3.22+`, `Dart` |
| Authentification | `Firebase Auth` |
| Base de données | `Firebase Realtime Database` |
| IoT | `ESP32`, `DHT11`, `contact sec`, `WiFiManager` |
| Notifications | `Firebase Functions` pour mail d'alerte |
| Graphiques | `fl_chart`, `intl`, `firebase_database` |
| Sécurité | RGPD, alertes < 5 min, SLA ≥ 99 % |

## 🗂️ Architecture des données (Firebase)

/apiculteurs/{apiculteurId}
/ruchers/{apiculteurId}/{rucherId}
/ruches/{apiculteurId}/{rucherId}/{rucheId}
/donnees/{apiculteurId}/{rucherId}/{rucheId}/{timestamp}


## 🔧 Installation locale

1. Cloner le projet :
```bash
git clone https://github.com/ton-org/ruche-connectee-flutter.git
cd ruche-connectee-flutter

2. Installer les dépendances :
flutter pub get

3.Configurer Firebase :

Télécharger le fichier google-services.json dans /android/app/

Vérifier la configuration Firebase dans lib/firebase_options.dart

4. Lancer l'application :
flutter run

🧪 Tests & Qualité
CI/CD via GitHub Actions (.github/workflows/flutter_ci.yaml)

Tests unitaires Flutter (flutter test)

Couverture (flutter test --coverage)

Lint automatique (flutter analyze)

📸 Preuves M6/M7
uptime_firebase_M6.png – disponibilité Firebase

log_email_T02.pdf – déclenchement alerte couvercle

historique_ruche_7j.csv – export données capteurs

APK : build/app/outputs/flutter-apk/app-debug.apk

🧑‍🔧 Comptes de test
| Rôle       | Login                                   | Mot de passe |
| ---------- | --------------------------------------- | ------------ |
| Admin      | [test@gmail.com](mailto:test@gmail.com) | 123456       |
| Apiculteur | [api1@email.com](mailto:api1@email.com) | 111111       |

🎯 Prochaines étapes
Mode hors ligne + synchronisation différée

Ajout caméra / IA pour analyse d’activité

Interface tablette (responsive Flutter)

📩 Contact
Projet pédagogique réalisé par Basara Migmar-Dolma – contact@pragma-tec.fr
Master Management Digital – Université [Nom] – 2025





## Email test@gmail.com
### Password 123456


## Need to check for 
- Sign Up ( inside the main.dart)
- forgot password ( inside the main.dart)
- sorting for the ruche needs to be done for the ruche.dart


## for admin Page
- sorting for all the pages needs to be done. 
- adding new apiculteur adds api8 instead of api_008 (apiculteur_listpage.dart)
- for the admin i need to see for the profile page. the password change is also not working as its not being stored inside the real time database. its only handled with the auth of firebase. 
- 
=======
### Password 123456


developpers email is tenyega23@gmail.com
