# Architecture et protocole 1

## Séparation des responsabilités

| Module | Responsabilité |
|---|---|
| `Core/Util.lua` | Identités, texte nettoyé, copies, hasard local et tokens indépendants |
| `Core/Roleplay.lua` | Noms TRP optionnels, correspondance de casse des royaumes et callbacks de profil |
| `Rules/Engine.lua` | État autoritaire, transitions atomiques, invariants, projections |
| `Session/Manager.lua` | Invitations, adhésion, intentions, présence, réparation, checkpoints |
| `Protocol/Codec.lua` | Sérialisation bornée sans exécution de code |
| `Transport/Wire.lua` | Encodage du canal, fragments, débit, files et expiration |
| `UI/Theme.lua`, `UI/UI.lua`, `Localization/Locale.lua` | Frames natives et localisation EN/FR |
| `Core/Demo.lua` | Clients simulés séparés avec le même moteur/protocole |
| `Core/Main.lua` | Événements Retail, enum C_ChatInfo, commandes, SavedVariables |

Les modules utilisent le namespace privé fourni par le chargeur WoW. Globals nécessaires uniquement : SavedVariables par personnage, alias de slash command et frame nommée pour Escape. Aucun seed global (`math.randomseed`), bibliothèque externe, import dynamique ou code exécutable reçu.

## Autorité et secrets

L'hôte conserve les rôles, la carte écartée, les faces associées aux slots et le générateur de mélange. `Engine.GetViewForPlayer` reconstruit une projection avec des champs autorisés. Cette projection est le seul chemin vers l'interface et vers les snapshots réseau, y compris pour l'hôte.

La partie publique comprend les sièges, slots opaques, révélations, progression, phase, révision et couple `currentHolderId`/`previousHolderId`. La partie privée ne contient que le camp de son destinataire et les comptes restants `SAFE/DEFUSE/BOMB`. Aucune position privée, graine ou permutation n'est transmise. Les rôles adverses et le reliquat sont montrés uniquement après une vraie fin ; une annulation efface les secrets.

Les IDs de slots proviennent d'un générateur de tokens indépendant du mélange. Ils restent stables dans une manche et sont remplacés à la redistribution. Ce générateur n'est pas une protection cryptographique ; la frontière de confiance est la projection et l'hôte n'est pas considéré comme un adversaire auquel cacher le paquet.

## Transitions

`LOBBY → PREPARING → ACTIVE → BETWEEN_ROUNDS → PREPARING`, ou `ACTIVE → GAME_OVER`. Revanche : `GAME_OVER → LOBBY` avec un nouvel ID de partie. Suspension et récupération sont des attributs distincts de la phase.

Le moteur valide l'état, copie un candidat, applique l'intention, vérifie ses invariants puis effectue le commit. Les rejets n'avancent ni révision, ni hasard de mélange, ni cartes, ni pince. L'identité de l'acteur vient de la session, jamais d'un champ déclaratif.

Le dernier transfert survit aux redistributions. Après une coupe : effet immédiat, victoire éventuelle, puis seulement fin de manche. Le rôle reste fixe. L'absence de cible ne déclenche jamais de passe ou d'exception à la variante.

### Pourquoi il reste toujours une cible

Au début d'une manche, chaque joueur a h cartes, avec h ≥ 2. Avant sa dernière coupe, il y a au plus N−1 cartes révélées. Pour épuiser toutes les N−2 cibles autorisées, il faudrait h(N−2) cartes révélées, donc au moins 2N−4. Pour N ≥ 4, 2N−4 > N−1. Une cible légale subsiste donc dans tout état accessible. Les tests vérifient aussi les parcours et les états de nombres de cartes symétriques.

## Enveloppes et authentification

Chaque enveloppe contient `v`, `version`, `ruleset`, `kind`, `sessionId`, `gameId`, `round`, `revision`, `requestId`, `payload`. Compatibilité stricte : version 1.1.0, protocole 1, ruleset `TB_RP_NO_RETURN_V1`.

- Une invitation possède un nonce, une expiration et un destinataire réel. Elle ne constitue pas une adhésion.
- JOIN/JOINED/JOIN_ACK établissent le siège. Le nombre de places est vérifié séquentiellement par l'hôte.
- Les clients envoient des intentions ; seuls les membres acceptés peuvent agir. Le serveur WoW fournit l'expéditeur réel via l'événement.
- Une CUT porte la partie, la manche, la révision et un ID. La déduplication se fait avant application ; une requête répétée reçoit le même résultat.
- READY tolère les révisions concurrentes au salon. ACK porte la manche et la partie ; la coupe attend que chacun ait reçu sa projection privée.
- Les coupes utilisent des deltas de projection. Un trou de révision demande un snapshot complet. Les confirmations intermédiaires ne causent pas une tempête de snapshots.

Les messages privés ne passent jamais sur groupe, raid, guilde ou canal public. Le mode démo ne traverse pas l'adaptateur C_ChatInfo. Les identités RP sont résolues localement via les accesseurs publics de TRP3 ; elles ne sont jamais des adresses réseau. Les vrais noms restent consultables au survol.

## Bornes et récupération

Le codec a une limite de 32 Kio, une profondeur de 12, 2048 éléments et 4096 octets par chaîne. Il n'évalue aucune expression Lua. Les données sont fragmentées en messages d'au plus 240 octets et codées pour éviter des caractères interdits sur le canal. Le débit propre est limité à environ 800 octets/s, avec contrôle des retours de l'API.

Les files, réassemblages, sollicitations, historiques et déduplications sont bornés. Les réassemblages expirent. Les contrôles légers de présence sont espacés de dix secondes ; absence au-delà de 45 secondes : suspension. Les retries ont une limite ; les délais ne sont pas des chronomètres de jeu.

Les SavedVariables `TimeBombRPDB` (options) et `TimeBombRPRecovery` (reprise) sont par personnage. L'hôte y conserve les secrets autoritaires et la déduplication ; les clients n'y conservent que leur projection. La restauration vérifie schéma, identité et invariants puis attend les révisions des participants. Un état distant plus récent suspend la reprise. Un checkpoint expire après 12 heures. Un état incohérent dont la projection publique reste valide est isolé sans ses secrets, pour permettre une fermeture propre. Les départs disposent de confirmations et de reprises bornées ; seules des traces temporaires sans secrets subsistent pour acquitter les doublons. Pas de migration ni de promesse de durabilité face à un crash brutal.

## Validation

Tests de référence : `Tests/test_engine.lua`, `test_network.lua`, `test_integration.lua`, `test_ui.lua`. Les clients du simulateur reçoivent des données sérialisées séparées ; ils ne partagent pas une table autoritaire. `Tests/wow_mock.lua` vérifie des contrats d'appel et interactions, mais ne remplace pas le runtime natif. Voir `VALIDATION.md` et `IN-GAME-CHECKLIST.md`.

## Présentation et emotes (1.1.0)

La main personnelle est construite uniquement depuis `private.counts`, dans l'ordre fixe DEFUSE/SAFE/BOMB, sans slot ni numéro de position. Les sièges adverses utilisent exclusivement leurs slots publics. Un aperçu de survol réutilisable montre le dos caché ou la face publique, avec groupes natifs Scale/Alpha ; il ne capture pas les clics. Changement de révision, fermeture, réduction et ouverture d'un tiroir le nettoient. Le mouvement réduit conserve l'agrandissement sans animation.

`App:Cut` mémorise une intention locale temporaire. `App:AnnounceCut` exige le même acteur, la même session/partie/manche, cible et slot, ainsi qu'une révision publique postérieure. Il consomme l'intention avant tout envoi via `C_ChatInfo.SendChatMessage(..., 'EMOTE')`. Les doublons et snapshots sans intention locale ne produisent rien. L'intention n'est pas sauvegardée ; elle expire après 60 secondes. L'option locale, la démo et le verrouillage du chat sont vérifiés. Aucun secret du moteur n'est lu pour composer l'emote.
