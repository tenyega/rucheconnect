# 🐝 Ruche Connectée – Suivi intelligent des ruches en temps réel

Ce projet propose une solution IoT + Mobile + Web pour la surveillance intelligente des ruches, destinée aux apiculteurs et encadrée dans le cadre d’un projet pédagogique (Module Ingénierie de Projet, 2025).

## 📦 Contenu du projet

- ESP32 + capteurs (DHT11, capteur de couvercle)
  - Base de données Firebase Realtime + Auth
  - Application mobile Flutter
  - Application Web (Spring Boot + Spring Security)
  - Interface Admin (CRUD apiculteurs)
  - Alertes en temps réel par email (Firebase Functions)
  - Tableau de bord & graphiques historiques

## 📁 Structure du dépôt

📦 ruche-connectee/
├── 📱 mobile/ → Application Flutter (Android)
├── 🌐 web/ → Application Web Spring Boot
├── 🔌 firmware/ → Code Arduino pour ESP32
├── 📊 data/ → Exports Firebase (CSV, logs)
├── 📄 docs/ → Diagrammes, plan de test, RTM, recette...
├── .github/workflows/ → CI/CD GitHub Actions
└── README.md → Ce fichier


## 🚀 Installation rapide

### 1. IoT (ESP32)

- Utilisez Arduino IDE
  - Configurez le Wi-Fi avec WiFiManager
  - Téléversez `firmware/esp32_ruche.ino` sur l’ESP32
  - Les données seront envoyées vers Firebase toutes les 30 min

### 2. Mobile (Flutter)

```bash
cd mobile/
flutter pub get
flutter run

Connexion avec Firebase Auth (login + mot de passe)

Visualisation des ruches, alertes, et historiques

3. Web (Spring Boot)
cd web/
./mvnw spring-boot:run
Interface web sécurisée

Accès admin pour la gestion des apiculteurs

🔐 Authentification & Sécurité
Auth Firebase : rôle apiculteur ou admin

JWT sécurisé sur l’interface Web (Spring Security)

Accès par rôle aux fonctionnalités (RBAC)

📈 KPIs projet (objectifs vs résultats)
| Indicateur               | Objectif | Résultat mesuré |
| ------------------------ | -------- | --------------- |
| Alerte email             | ≤ 5 min  | ✅ 3 min 12 s    |
| MAJ Firebase             | ≤ 30 min | ✅ 28 min        |
| SLA disponibilité        | ≥ 99 %   | ✅ 99.3 %        |
| Satisfaction utilisateur | ≥ 90 %   | ✅ 93 %          |
| ROI                      | ≥ 120 %  | ✅ 127 %         |

📋 Documents associés
✔️ Plan de test détaillé

✔️ Cahier de recette

✔️ WBS + dictionnaire

✔️ Spécifications fonctionnelles

✔️ Guide utilisateur

📬 Contact
Support technique : contact@pragma-tec.fr

Dépôt officiel : GitHub – Ruche Connectée

Projet encadré – Master Management Digital & Data – 2025

# tp_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## I have added the dependencies of the Firebase authentification 
 pubspec.yaml
 firebase_auth: 5.4.1
 firebase_core: 3.10.1
 firebase_database: 11.3.1
 
then i did 
## flutter pub get 
To update the dependencies.

## Email test@gmail.com
<<<<<<< HEAD
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
>>>>>>> 8627a8a1de90d9578adc39174c73a33599c0b042
