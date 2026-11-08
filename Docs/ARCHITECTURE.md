# Architecture

`App/TidivaApp.swift` ouvre un stockage SwiftData local, puis affiche l’onboarding ou les quatre onglets. Une erreur d’ouverture affiche un état d’erreur explicite sans effacer les données.

- `Data/Reset.swift` : tâche ponctuelle persistée et catalogue de pièces/actions.
- `Services/PlanningRules.swift` : calcul pur du nombre de tâches et sélection sous budget de temps.
- `Services/Planner.swift` : sélection locale par Foundation Models si disponible, validation stricte contre un catalogue d’actions ; sinon sélection déterministe. Chaque tâche du plan représente cinq minutes estimées.
- `Screens` : Today, pièces, planification, statistiques, onboarding et réglages.
- `Design/Theme.swift` : couleurs adaptatives, Page, PrimaryButton et présentation des cartes.

L’IA ne fournit jamais d’instruction ménagère libre sauvegardée : seules des chaînes identiques au catalogue sont acceptées. Les durées affichées sont estimées. La validation des tâches et du plan est persistée explicitement ; les erreurs provoquent un rollback et une alerte.

Avant la récurrence, séparer TaskDefinition, Completion et RoutineSession avec une migration testée. Le booléen ou timestamp actuel ne doit pas servir de modèle définitif des tâches récurrentes. Les statistiques actuelles comptent les tâches ponctuelles terminées, et non des sessions enregistrées.

Membership vérifie les transactions StoreKit avant de déterminer les droits. Les rappels utilisent UserNotifications. Le stockage n’active pas CloudKit implicitement.
