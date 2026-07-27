# Vérification sur iPhone 14 Plus

## Xcode

1. Ouvrir `Myrtine.xcodeproj` avec Xcode 26.
2. Sélectionner `iPhone 14 Plus` avec iOS 26.
3. Exécuter le schéma `Myrtine` avec `Command-U`.
4. Ouvrir le rapport de tests puis les pièces jointes de `MyrtineUITests`.

Chaque pièce jointe nommée `01-…`, `02-…`, etc. est une capture prise après l'action correspondante. Les parcours couvrent l'accueil, les diagnostics, le rendu Markdown, les dossiers mail, la lecture plein écran, la rédaction riche, les brouillons et le mode avion.

## Ligne de commande macOS

```bash
xcodebuild test \
  -project Myrtine.xcodeproj \
  -scheme Myrtine \
  -destination 'platform=iOS Simulator,name=iPhone 14 Plus,OS=latest' \
  -resultBundlePath TestResults/Myrtine.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Pour tester sur un iPhone physique, sélectionner l'équipe Apple dans Signing & Capabilities et remplacer l'identifiant `fr.myrtine.admin` si celui-ci est déjà utilisé par un autre compte.

## Depuis Windows avec GitHub Actions

1. Ouvrir l'onglet `Actions` du dépôt GitHub.
2. Choisir `iOS 26 verification`, puis `Run workflow`.
3. Lorsque le travail est terminé, télécharger l'artefact `Myrtine-iPhone-14-Plus`.
4. Ouvrir le dossier `Screenshots` pour examiner chaque écran.

L'archive `Myrtine-Simulator.app.zip` contenue dans l'artefact est un build ARM pour simulateur. Elle peut être envoyée à un service de simulateur iOS dans le navigateur qui accepte les bundles `.app` compressés. Elle ne peut pas être installée directement sur un iPhone : une distribution TestFlight signée reste nécessaire pour cela.
