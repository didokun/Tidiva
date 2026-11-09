# Configuration et vérification

Environnement inspecté le 7 novembre 2026 : Xcode 26.6, SDK iOS et iOS Simulator 26.5. Les runtimes de simulateur iOS/watchOS 26.0 sont signalés indisponibles. Les destinations génériques Xcode signalent également que les composants iOS 26.5 sont manquants.

Compilation du code sans lancement de simulateur :

```sh
xcodebuild -project Tidiva.xcodeproj -target Tidiva -sdk iphonesimulator -configuration Debug SYMROOT=/tmp/Tidiva-products OBJROOT=/tmp/Tidiva-objects CODE_SIGNING_ALLOWED=NO build
```

Cette commande compile et lie l’application pour le SDK simulateur installé. Elle ne valide ni l’affichage ni l’exécution de SwiftData et Foundation Models. Un runtime de simulateur compatible ou un appareil configuré reste nécessaire pour les tests interactifs.

Pour la signature, remplacer `com.example.tidiva` par un identifiant disponible et sélectionner l’équipe Apple Developer. Le changement d’identifiant crée une autre identité d’application : aucune migration entre les anciens et nouveaux conteneurs signés n’est annoncée.

CloudKit : volontairement désactivé jusqu’à l’ajout des capacités, d’un conteneur privé et des tests de migration et synchronisation. Foundation Models : vérification runtime iOS 26 et disponibilité du modèle, sinon fallback déterministe.

## Profil avec Apple

Debug utilise le profil local et peut être signé avec une équipe personnelle. Release inclut le bouton Apple et le droit correspondant. Pour tester Release avec une équipe compatible, activer Sign in with Apple sur l’App ID de Tidiva, puis actualiser le profil de provisionnement dans Xcode. Le projet déclare le droit dans Tidiva.entitlements. Tester sur un iPhone connecté à un compte Apple avec authentification à deux facteurs. Vérifier le partage et le masquage de l’e-mail, l’annulation, puis une deuxième autorisation (les champs peuvent être absents). Le profil est local et facultatif. La suppression locale efface les coordonnées dans Tidiva. Les autorisations Apple se gèrent dans les réglages du compte Apple.

## Rappels, abonnement et publicités

Dans Réglages, activer deux rappels (9 h et 19 h) ou trois (13 h en plus). Ils utilisent l’heure locale de l’appareil et peuvent être désactivés. Pour tester le refus iOS, réautoriser Tidiva depuis les réglages de notifications du téléphone.

Pour tester le paiement localement : Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → Tidiva.storekit. Les produits de test coûtent 5 USD par mois, 50 USD par an et 80 USD à vie. Les deux abonnements proposent un essai gratuit de 7 jours aux comptes admissibles. Vérifier l’achat, la restauration et l’expiration depuis le gestionnaire de transactions Xcode. Pour TestFlight et la production, créer les deux produits tidiva.premium.monthly et tidiva.premium.yearly dans le même groupe App Store Connect. Configurer pour chacun une offre de lancement « Essai gratuit » d’une semaine dans les territoires souhaités. Créer tidiva.premium.lifetime comme achat non consommable. Définir tarifs, conditions, URL de confidentialité et contrats. La vue StoreKit affiche les prix localisés fournis par la boutique.

Debug utilise les identifiants de démonstration Google. Release utilise les identifiants AdMob de Tidiva pour l’application, l’interstitiel et la bannière, configurés dans App.xcconfig. Si TIDIVA_ADMOB_BANNER_ID est vide, aucune bannière n’est demandée en Release. Une bannière 320 × 50 est prévue en bas d’Aujourd’hui, du calendrier, des pièces (liste et détail), des routines (liste et détail) et de la progression, dans un espace réservé hors du contenu. Premium masque toutes les publicités ; aucune demande n’est effectuée tant que l’abonnement est inconnu ou pour un profil de moins de 18 ans. Vérifier l’apparition, l’échec de chargement, la navigation et la disparition après achat Premium sur appareil. Publier les messages de consentement dans Privacy & messaging, compléter les déclarations App Privacy et configurer les identifiants SKAdNetwork des réseaux utilisés selon le guide Google. L’interstitiel reste présenté à la fin d’une séance après vérification de l’abonnement et du consentement. Les coordonnées du profil et les tâches ne sont pas passées dans les requêtes publicitaires.
