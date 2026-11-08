# Publier Tidiva sur l’App Store pour la première fois

Guide pour la version iPhone 1.0, préparé le 8 novembre 2026. Pars de l’étape 1 si tu as seulement lancé l’app depuis Xcode. Tu peux t’arrêter après l’étape 8 pour faire une bêta privée. La mise en ligne publique intervient à l’étape 10.

## Avant de commencer

| Outil | Ce que tu y fais |
|---|---|
| Xcode, sur ton Mac | Compiler Tidiva, tester les achats localement, signer la version destinée à Apple et l’envoyer. |
| Apple Developer | Inscrire ton compte au programme de distribution, enregistrer l’identité technique de Tidiva et autoriser ses capacités. |
| App Store Connect | Créer la fiche publique, configurer les prix, inviter des testeurs, envoyer la version à l’équipe de validation Apple. |
| TestFlight, sur ton iPhone | Installer la version traitée par Apple et vérifier ce qu’un utilisateur recevra. |
| Google AdMob | Créer l’emplacement publicitaire, configurer le consentement et suivre la diffusion des annonces. |

**Point de départ du projet.** L’icône, le parcours initial, les routines, la planification, les rappels, le calendrier, l’achat Premium et la restauration sont présents. La compilation simulateur a réussi. Le projet utilise encore le bundle ID `com.example.tidiva`, un identifiant d’app publicitaire de démonstration et un identifiant d’interstitiel Release vide. Les offres dans [Tidiva.storekit](../Tidiva.storekit) sont des offres de test. L’état de tes comptes externes, de tes contrats et de tes produits de vente reste à vérifier dans leurs consoles.

## 1. Obtenir le compte qui publiera l’app

- [ ] Connecte-toi au [portail Apple Developer](https://developer.apple.com/account/) avec le compte qui doit posséder Tidiva. Vérifie ton inscription à l’Apple Developer Program. Si tu publies au nom d’une société, vérifie l’identité du vendeur avant de t’inscrire. [Inscription](https://developer.apple.com/programs/enroll/)
- [ ] Dans **Xcode → Settings → Accounts**, ajoute ce compte et vérifie que l’équipe du programme apparaît. Ton ancienne erreur « Personal development teams … do not support Sign In with Apple » correspond au choix d’une équipe personnelle gratuite.
- [ ] Ouvre [App Store Connect](https://appstoreconnect.apple.com/). Dans **Business**, le titulaire du compte accepte les accords demandés, dont le contrat pour les apps payantes, puis complète les informations fiscales et bancaires pour vendre Premium. Si tu distribues dans l’Union européenne, complète aussi la déclaration de statut de professionnel demandée par Apple. [Contrats Apple](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)

**Vérification** — tu peux accéder à **Apps**, identifier la bonne équipe et voir le statut de chaque accord. Conserve les coordonnées bancaires, documents d’identité et accès aux comptes hors du dépôt de code.

## 2. Donner à Tidiva son identité définitive

1. Choisis un identifiant unique, par exemple `com.tonentreprise.tidiva`, en remplaçant le nom d’exemple par le tien. Ce **bundle ID** lie l’app installée, sa fiche et ses achats.
2. Dans **Apple Developer → Certificates, Identifiers & Profiles → Identifiers**, enregistre un **App ID** explicite pour cet identifiant et active **Sign in with Apple**. Le projet utilise cette capacité en Release. [Enregistrer un App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/)
3. Ouvre [App.xcconfig](../App.xcconfig) et remplace la valeur de `PRODUCT_BUNDLE_IDENTIFIER`. Dans Xcode, sélectionne le projet bleu → **Targets → Tidiva → Signing & Capabilities**. Vérifie le bundle ID, l’équipe et **Automatically manage signing** pour Debug et Release.
4. Lance Tidiva sur ton iPhone. Un nouveau bundle ID donne une installation et un stockage local distincts. Garde ton ancienne installation si tu tiens aux routines utilisées pendant le développement.

**Vérification** — la cible Release utilise la bonne équipe et le droit Sign in with Apple. Note le bundle ID exact pour l’étape suivante.

## 3. Créer la fiche dans App Store Connect

Dans **Apps → + → New App**, indique iOS, le nom **Tidiva** s’il est disponible, la langue principale, le bundle ID de l’étape 2 et un SKU interne de ton choix, par exemple `TIDIVA-IOS-001`. Le SKU sert à ton suivi. Note aussi l’identifiant Apple numérique créé pour la fiche. Choisis un téléchargement gratuit si les revenus viennent de Premium et de la publicité. [Créer la fiche Apple](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)

**Vérification** — ouvre la fiche et compare son bundle ID caractère par caractère avec celui de Xcode.

## 4. Préparer les pages publiques et la confidentialité

- [ ] Publie une **page d’assistance** avec un moyen de te contacter et les explications les plus utiles au lancement : gérer Premium, retirer les événements Apple et supprimer ses données locales.
- [ ] Publie une **politique de confidentialité** qui décrit le fonctionnement réel. Passe en revue le profil local, l’autorisation Apple, les rappels, les événements que l’utilisateur exporte, les achats et les données traitées par les SDK publicitaires. Explique les choix de consentement, la suppression et le contact. Vérifie ces affirmations sur la version Release.
- [ ] Ajoute dans l’app un lien vers cette politique, notamment dans **Réglages → Données et confidentialité**. Ajoute aussi sur la page Premium des liens fonctionnels vers la politique et les conditions d’utilisation applicables. Si tu utilises le contrat standard Apple, vérifie que la fiche de vente y renvoie également. [Règles Apple, confidentialité et abonnements](https://developer.apple.com/app-store/review/guidelines/)
- [ ] Complète **App Privacy** dans App Store Connect en tenant compte d’AdMob et des SDK tiers. Génère le rapport de confidentialité depuis l’archive Xcode. Tidiva utilise directement `UserDefaults` : ajoute le manifeste `PrivacyInfo.xcprivacy` de la cible et déclare la raison autorisée correspondant à cet usage. Vérifie si ta configuration publicitaire effectue du suivi nécessitant l’autorisation ATT. [Manifeste Apple](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) · [Données collectées](https://developer.apple.com/app-store/app-privacy-details/)
- [ ] Vérifie la différence entre **réinitialiser Tidiva**, **retirer les événements déjà exportés** et **résilier Premium**. Si tu proposes la création d’un compte, vérifie aussi le parcours de suppression de compte et la révocation de l’autorisation Sign in with Apple. [Suppression de compte](https://developer.apple.com/support/offering-account-deletion-in-your-app/)

**Vérification** — ouvre les liens depuis un iPhone, en navigation privée. Un utilisateur doit pouvoir les lire sans compte et contacter l’assistance.

## 5. Configurer les trois offres qui seront vendues

Dans la fiche Tidiva, ouvre **Monetization → Subscriptions** pour les deux abonnements et **In-App Purchases** pour l’achat à vie. Recopie les identifiants ci-dessous exactement. Le code les utilise pour demander les produits à Apple.

| Offre Tidiva | Identifiant produit | Configuration prévue |
|---|---|---|
| Mensuelle | `tidiva.premium.monthly` | Abonnement renouvelable d’un mois, prix cible US de 5 USD, essai gratuit d’une semaine. |
| Annuelle | `tidiva.premium.yearly` | Abonnement renouvelable d’un an, prix cible US de 50 USD, essai gratuit d’une semaine. |
| À vie | `tidiva.premium.lifetime` | Achat **non consommable**, paiement unique, prix cible US de 80 USD. |

1. Crée un groupe d’abonnements **Tidiva Premium**. Place les formules mensuelle et annuelle au même niveau de service si elles donnent les mêmes avantages. Choisis les prix disponibles et vérifie les tarifs localisés par territoire.
2. Pour chaque abonnement, configure l’offre de lancement **Free Trial → 1 week**, les pays et la période de disponibilité. L’éligibilité se gère au niveau du groupe : passer du mensuel à l’annuel ne doit pas promettre un deuxième essai. [Configurer les essais](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/)
3. Ajoute noms et descriptions FR/EN, disponibilités, captures de l’écran d’achat pour la review et notes de test. Dans l’app, vérifie le prix après l’essai, la périodicité, la restauration et la gestion de l’abonnement. Le code affiche un prix de référence barré de 10 USD dans certains cas : retire-le ou vérifie que tu peux justifier cette comparaison avant publication.
4. Vérifie que chaque produit est prêt à être soumis. À l’étape 10, joins les premiers achats à la version 1.0. [Soumettre les achats](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)

**Test gratuit avant l’envoi** — dans Xcode, **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → Tidiva.storekit**. Lance avec ⌘R, ouvre **Réglages → Abonnement**, choisis une offre et confirme. Inspecte ou supprime la transaction de test via **Debug → StoreKit → Manage Transactions**. Recommence plus tard sur TestFlight : ce deuxième test vérifie les produits configurés chez Apple. [Guide StoreKit](https://developer.apple.com/documentation/Xcode/setting-up-storekit-testing-in-xcode)

## 6. Brancher les publicités de production

1. Dans AdMob, ajoute l’app iOS et crée une unité **Interstitial**. Si Tidiva est encore inédite, tu pourras relier sa fiche publique une fois disponible. Copie les deux identifiants. L’**App ID** contient un tilde `~` et l’identifiant de l’**unité publicitaire** contient une barre `/`.
2. Dans les réglages de build de la cible Tidiva, mets tes valeurs pour **Release** : `TIDIVA_ADMOB_APP_ID` et `TIDIVA_ADMOB_INTERSTITIAL_ID`. Garde les valeurs de démonstration pour Debug. Attention : le projet partage actuellement l’App ID de démonstration via le fichier xcconfig. Vérifie les valeurs finales de chaque configuration.
3. Configure et publie les messages nécessaires dans **Privacy & messaging**. Complète les entrées `SKAdNetworkItems` du fichier [Tidiva-Info.plist](../Tidiva-Info.plist) selon les réseaux utilisés. Pour tester sur ton téléphone avec de vrais identifiants, déclare-le comme appareil de test avant d’interagir avec une annonce. [Intégration iOS](https://developers.google.com/admob/ios/quick-start) · [Annonces de test](https://developers.google.com/admob/ios/test-ads)
4. Sur le domaine du site développeur, publie à la racine le fichier `app-ads.txt` fourni par **ton** compte. Renseigne le site développeur dans la fiche, puis contrôle l’état de vérification dans AdMob après publication. [Guide app-ads.txt](https://developers.google.com/admob/ios/app-ads)

**Vérification** — en version gratuite, termine au moins une tâche puis la séance. Une annonce chargée peut apparaître à ce moment. Teste aussi sans annonce disponible : la séance doit se terminer normalement. Active Premium et répète le parcours pour vérifier l’absence de publicité.

## 7. Archiver et envoyer la première build

Une **version** est le numéro visible du public, par exemple 1.0. Une **build** est un envoi précis de cette version, par exemple 1.0 (1), puis 1.0 (2) après un correctif.

1. Dans Xcode, ouvre le schéma **Tidiva**, choisis une destination iOS générique ou un iPhone physique. Vérifie sous **Edit Scheme → Archive** que la configuration est **Release** et que la version et le numéro de build sont ceux attendus.
2. Choisis **Product → Archive**. Dans **Window → Organizer → Archives**, sélectionne l’archive et utilise **Validate App** si proposé. Vérifie les erreurs de signature, d’entitlements et de confidentialité.
3. Choisis **Distribute App → App Store Connect → Upload** (le libellé peut varier selon Xcode). À la fin, ouvre la fiche **TestFlight** et attends la fin du traitement Apple. Réponds aux questions de conformité au chiffrement selon l’utilisation réelle de l’app. [Envoyer une build](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) · [SDK minimum accepté](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)

**Vérification** — tu vois la build traitée sous TestFlight. Un upload dans App Store Connect ne publie pas l’app sur la boutique.

## 8. Faire une bêta TestFlight sur un vrai iPhone

Crée un groupe **Internal Testing**, ajoute un membre autorisé de ton équipe, assigne la build, puis ouvre son invitation dans l’app TestFlight sur l’iPhone. Pour inviter des personnes extérieures, crée un groupe **External Testing**, renseigne les informations de bêta et prévois le passage en Beta App Review lorsque demandé. [Démarrer avec TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

| Parcours à essayer | Résultat attendu |
|---|---|
| Première installation en français, puis en anglais et en mode sombre | L’accueil explique Tidiva, les champs nom/prénom restent lisibles et aucune tâche n’est imposée. |
| Profil hybride, bureau lundi à mercredi | Les mêmes jours sont cochés dans Travail et dans les jours à éviter. Les dates proposées respectent le choix. |
| Deux étages, une pièce décochée, une tâche personnalisée | Le récapitulatif montre les bonnes pièces, le titre et la durée. Fermer puis rouvrir l’éditeur restitue la sélection enregistrée. |
| Calendrier Apple autorisé puis refusé | La routine fonctionne dans les deux cas. Deux synchronisations successives évitent les doublons. Retirer les événements préserve les rendez-vous personnels. |
| Rappels et connexion Apple | Un rappel arrive à l’heure choisie sur iPhone verrouillé. Teste aussi refus, modification et désactivation. Vérifie Sign in with Apple sur cette build Release. |
| Premium mensuel, annuel et à vie | Prix et périodes visibles. L’essai n’apparaît que pour un compte admissible. Vérifie achat, annulation de la feuille d’achat, restauration, changement d’offre, résiliation et expiration. |
| Retour dans l’app après fermeture et mise à jour depuis une build antérieure | Les données et les droits sont relus correctement. Teste la réinitialisation uniquement sur un profil de test. |

Si un parcours échoue, note l’iPhone, la version iOS, le numéro de build et les étapes exactes. Corrige, incrémente le numéro de build, puis reprends à l’étape 7.

## 9. Préparer ce que les visiteurs verront

- [ ] Dans la fiche de version, complète nom, sous-titre, description, mots-clés, catégorie, copyright, URL d’assistance et localisations FR/EN.
- [ ] Prends des captures d’une **vraie routine de démonstration**, sans données personnelles. Montre dans l’ordre le bénéfice principal : planning adapté aux jours de bureau, sélection des pièces et des tâches, puis séance du jour. Respecte les dimensions et emplacements demandés par App Store Connect. [Captures acceptées](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [ ] Sélectionne les territoires de distribution. Termine le questionnaire d’âge et les informations de confidentialité. Vérifie l’icône et la lisibilité des captures sur téléphone.
- [ ] Décide de la promesse de la V1. Aujourd’hui, Tidiva planifie les tâches sélectionnées sur des dates. La répétition automatique chaque semaine reste une évolution produit : annonce-la dans la fiche seulement quand elle aura été implémentée et testée.

## 10. Soumettre puis publier

1. Ouvre la version **1.0**, sélectionne la build testée à l’étape 8 et ajoute les premiers achats et abonnements à la même soumission. Vérifie le résumé des éléments qui partiront en review.
2. Dans **App Review Information**, donne un contact joignable et le chemin pour tester l’app. Exemple de note à adapter : « Le profil local est facultatif. Après le questionnaire, toucher Créer ma routine, choisir une pièce et une tâche, puis confirmer. La boutique se trouve dans Réglages → Abonnement. La synchronisation Apple et les notifications sont facultatives. »
3. Pour maîtriser le jour du lancement, sélectionne la **publication manuelle**. Clique sur **Add for Review**, vérifie la soumission, puis sur **Submit for Review**. [Soumettre une version](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app-for-review/)
4. Surveille les messages d’App Review. Une demande d’explication peut se régler en répondant dans App Store Connect. Si une correction de code est nécessaire, envoie une nouvelle build et sélectionne-la pour la soumission.
5. Après approbation, si tu as choisi la publication manuelle, déclenche **Release This Version** au moment souhaité. Vérifie ensuite la fiche publique depuis un territoire activé et installe l’app via l’App Store.

## Les premiers jours après le lancement

- [ ] Ouvre la fiche publique, la page d’assistance et les liens de confidentialité. Vérifie les prix et les langues tels qu’un client les voit.
- [ ] Dans App Store Connect et Xcode Organizer, surveille les plantages, les retours de test et les premiers problèmes d’achat. Dans AdMob, vérifie le lien avec la fiche publique, l’état de l’app et la disponibilité des annonces.
- [ ] Pour un correctif après publication, prépare une nouvelle version, par exemple **1.0.1**, augmente le numéro de build, reteste le parcours corrigé dans TestFlight et soumets la mise à jour.

## Si tu bloques

| Symptôme | Première vérification |
|---|---|
| Xcode affiche « Personal Team » ou refuse Sign in with Apple | Vérifie l’inscription au programme, la connexion du compte dans Xcode, la Team de Release et la capacité sur le bon App ID. |
| Les prix sont indisponibles depuis Xcode | Vérifie le fichier StoreKit actif sous Run → Options, puis relance avec ⌘R. |
| Les prix apparaissent dans Xcode mais pas dans TestFlight | Vérifie les identifiants produits exacts, les disponibilités, les métadonnées, les tarifs et le statut du contrat payant dans App Store Connect. |
| L’archive est envoyée mais invisible sur la fiche de version | Vérifie le bundle ID, le numéro de version, la fin du traitement et les éventuels messages d’Apple. |
| Tu attends un essai de 7 jours et il n’apparaît pas | Vérifie l’offre du territoire et l’éligibilité du compte dans ce groupe. Recommence avec un environnement de test propre. |
| L’annonce de fin de séance ne s’affiche pas | Vérifie d’abord version gratuite, âge autorisé, consentement, identifiant interstitiel de la build et disponibilité de l’annonce. Une absence de remplissage peut être normale. |

**Première action conseillée pour Tidiva** — termine les étapes 1 et 2 avant de créer les achats chez Apple. La fiche, les achats et les tests de la future version publique doivent tous pointer vers le même bundle ID.
