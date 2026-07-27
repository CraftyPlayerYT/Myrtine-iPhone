# Myrtine iOS

Application d'administration Myrtine native pour iPhone, écrite en SwiftUI et UIKit.

## Prérequis

- macOS avec Xcode 26 ou plus récent
- iOS 26 SDK
- iPhone 14 Plus Simulator

Ouvrir `Myrtine.xcodeproj`, sélectionner le schéma `Myrtine`, puis lancer l'app.

## Tester sans Mac

Le workflow GitHub Actions `iOS 26 verification` crée un simulateur iPhone 14 Plus, compile l'application, exécute les tests unitaires et les parcours d'interface puis publie un artefact `Myrtine-iPhone-14-Plus`.

Cet artefact contient :

- les captures PNG prises après chaque action importante ;
- le rapport Xcode complet `Myrtine.xcresult` ;
- le journal de compilation ;
- `Myrtine-Simulator.app.zip`, chargeable dans un simulateur iOS en ligne compatible avec les builds Apple Simulator.

Les données sont conservées localement avec SwiftData. Les requêtes réseau sont mises en attente hors ligne et reprises à la reconnexion. La clé Perplexity facultative est enregistrée dans le Trousseau iOS depuis Réglages > Intelligence artificielle; aucune clé privée n'est incluse dans les sources.

Le schéma `MyrtineUITests` couvre les parcours principaux et attache une capture après chaque action importante. Les captures apparaissent dans le rapport de tests Xcode.
