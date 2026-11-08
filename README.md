# Tidiva

A little reset. A calmer home.

Application iOS native de routines ménagères pour le marché américain. Le projet Xcode se trouve dans `~/Server/Tidiva/Tidiva.xcodeproj`.

## Lancer

Ouvrir `Tidiva.xcodeproj`, sélectionner le schéma Tidiva et un simulateur iPhone. Le code cible iOS 17 et utilise les SDK Xcode 26 pour Foundation Models, isolé à iOS 26. Si Xcode indique qu’iOS n’est pas installé, installer les composants iOS et un runtime de simulateur depuis Xcode → Settings → Components. Sur appareil physique, définir l’équipe Apple et un identifiant d’application disponible dans `App.xcconfig`.

## Implémenté

- Identité Tidiva, palette sauge, apparence claire et sombre, composants SwiftUI réutilisables.
- Previews des quatre onglets avec une maison d’exemple en mémoire, identifiée « Sample home », et preview du premier lancement.
- Configuration initiale en quatre étapes : profil facultatif, logement, pièces, durée quotidienne.
- Première routine créée selon les pièces choisies et le budget de temps.
- Today : progression réelle, tâches, ajout manuel et sessions guidées avec validation et passage d’une tâche.
- My Home : tâches regroupées par pièce et accès au détail.
- Routines : quatre modèles photographiés (retour du bureau, pause en télétravail, invités, dimanche), favori, budget ajustable et sélection locale selon les pièces, les étages et les dernières complétions. Le rythme hybride permet de choisir les jours de télétravail.
- Plan par pièce : sélection d’actions validées par le modèle local compatible, sinon routine déterministe hors ligne ; ajout à Today.
- Progress : graphique sur sept jours à partir des tâches enregistrées.
- Stockage local SwiftData ; préférences locales. Profil sur l’appareil, avec import facultatif du nom et de l’adresse e-mail via Apple.

Les tâches enregistrées sont ponctuelles dans cette version : la récurrence et un historique de complétions séparé restent à implémenter. Le nom interne du magasin SwiftData `HomeReset` est conservé afin de préserver la possibilité de retrouver les données existantes ; le changement de bundle identifier peut toutefois changer le conteneur de l’application lors d’une réinstallation.

## Vérification

Voir `Docs/SETUP.md` pour les commandes et les limites de l’environnement. Les huit contrôles de planification se lancent avec :

```sh
swiftc App/Services/PlanningRules.swift Tests/main.swift -o /tmp/tidiva-planning-tests
/tmp/tidiva-planning-tests
```

Les rappels locaux sont facultatifs. Premium retire la bannière et étend le suivi à 30 jours. La configuration StoreKit de test et les identifiants AdMob de production sont détaillés dans Docs/SETUP.md.
