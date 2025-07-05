# corsicaquiz

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Nouveauté

* Possibilité de demander une **Revanche** depuis l'écran de résultat d'un duel.

## Confidentialité iOS

L'application utilise le package `app_tracking_transparency` pour demander
l'autorisation de suivi publicitaire au démarrage.

## Indexes Firestore

Les index composites nécessaires à l'application sont définis dans `firestore.indexes.json` à la racine du projet. Pour les déployer, exécutez :

```bash
firebase deploy --only firestore:indexes
```
