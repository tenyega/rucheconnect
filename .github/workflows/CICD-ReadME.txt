CI/CD flutter project
- 1. Prerequisites
	Your Flutter project is version-controlled with Git and hosted on GitHub.

	You have a working pubspec.yaml.

2. Create Workflow File
	Create this file in your repo:
	.github/workflows/flutter_ci.yaml

3. flutter_ci.yaml code 
		name: Flutter CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.6' # or your desired version

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze code
        run: flutter analyze

      - name: Run tests
        run: flutter test

4. commit 
	git add .github/workflows/flutter_ci.yaml
	git commit -m "Add Flutter CI GitHub Actions workflow"
	git push origin main

4. Check it on GitHub
Go to your GitHub repo → Actions tab. You should see the workflow running automatically on push or pull requests to main.
