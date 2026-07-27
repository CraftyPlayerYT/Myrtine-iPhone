# Rapport de vérification

Date : 27 juillet 2026

## Vérifié depuis Windows

- 33 fichiers Swift, sans dépendance tierce.
- Interface native SwiftUI/UIKit; aucune WebView, iframe ou interface HTML.
- Catalogues JSON et schéma Xcode XML valides syntaxiquement.
- Icône d'application PNG opaque de 1024 × 1024 pixels.
- Aucun bouton vide ou action factice détecté par la revue statique.
- Données locales SwiftData, file d'attente hors ligne et reprise à la reconnexion.

## Vérifié sur les services réels

- Serveur : `2026-07-24-official-aid-table-v20`.
- Diagnostic admin : état `recue`, fournisseur Perplexity, modèle `sonar-pro`.
- Réponse : 2 106 caractères et tableau Markdown présent.
- Durée du test : environ 23,5 secondes.
- E-mail : état `email_envoye`.
- Relève IMAP : état `mail_sync`.
- Supabase : une ligne `sent` et une ligne `received` retrouvées pour le même message; balise de texte gras conservée dans le corps HTML.
- Les données de test ont ensuite été supprimées de Supabase.

## À exécuter sur macOS

Le SDK iOS et le simulateur Apple ne sont pas disponibles sous Windows. La compilation Swift, les tests XCUITest et leurs captures doivent être lancés avec Xcode 26 sur un simulateur iPhone 14 Plus. La commande exacte et le workflow GitHub Actions sont fournis dans `TESTING.md` et `.github/workflows/ios-tests.yml`.
