# Validation exécutée — 13 octobre 2026

Version **1.0.0** ; cible de sources Retail **12.1.5 (70340) / 120105**.

## Résultats obtenus

| Vérification | Résultat |
|---|---|
| `python3 tools/test.py` | **43 suites réussies, 0 échec**, VM Lua 5.1 (Lupa 2.8) |
| `python3 tools/assets_build.py --verify` | 12 textures vérifiées : BGRA32 non compressé, POT, alpha, orientation, empreintes, géométrie identique des cartes |
| `python3 tools/preview_ui.py` | Aperçus 4/8 générés à partir des appels UI simulés et inspectés ; rendu approximatif |
| `python3 tools/build.py` | ZIP installable créé avec `TimeBombRP/TimeBombRP.toc` à la racine logique |
| `python3 tools/check.py` | Syntaxe Lua 5.1, ordre TOC, 10 modules, chemins/12 textures et octets exacts du ZIP |

Les tests du moteur couvrent les cinq tailles de table, les secrets des rôles écartés, les comptes de câbles, l'ordre atomique des victoires, le dernier coup de la quatrième manche et la conservation entre manches. La variante anti-retour est testée sur les rejets atomiques, les redistributions, les reprises, 300 parcours générés et une exploration exhaustive des états symétriques de nombres de cartes.

La simulation réseau utilise des clients distincts et le codec réel. Elle couvre capacité concurrente, nonce/version/ruleset, faux expéditeur, READY concurrent, JOINED perdu, intentions dupliquées, RESULT perdu, patch absent/réordonné, snapshots de réparation, départs/confirmations perdus, reconnection, checkpoints périmés/corrompus/antérieurs et reprise de l'hôte. Les projections mal formées sont rejetées avant l'interface.

**Mesure du test à huit clients : 35,1 secondes de préparation initiale à 800 octets/s.** Les huit clients deviennent actifs sans fausse déconnexion ; la coupe converge ensuite dans la fenêtre de 20 secondes du test, sans accumulation incontrôlée. Ce sont des mesures du simulateur et du débit propre de l'addon, pas de la latence réelle d'un royaume WoW.

Les tests UI vérifient le chargement des composants, les arguments `SetFont`, la sélection locale et la confirmation, les cartes interdites, les invitations explicites, les tiroirs, le format réduit, les informations privées périmées et l'absence de croissance des frames sur 80 rendus successifs. L'adaptateur Retail est exercé avec des retours numériques d'API et la démo n'émet aucun message réseau live.

## Limites de cette validation

- **Aucun test dans le client WoW** n'a été exécuté.
- **Aucun essai avec quatre vrais clients non groupés** n'a été exécuté.
- Les captures d'aperçu ne sont pas des captures WoW. Elles servent à examiner la disposition, avec des métriques et un ordre de dessin approximatifs.
- Les textures sont vérifiées comme fichiers TGA ; leur affichage exact dans le moteur natif reste à valider.
- Les sources Blizzard vérifient les signatures et restrictions, pas la disponibilité de la route WHISPER sur votre royaume.
- Le temps de préparation dépend du volume de données, du débit et des autres addons utilisant les communications.
- Les sauvegardes sont écrites selon le cycle normal de SavedVariables ; aucune garantie contre une panne brutale. Elles expirent après 12 heures.
- CI fournie, résultats locaux rapportés ici. Ne pas assimiler l'existence du workflow à une exécution GitHub Actions réussie.

La recette restante est décrite dans [IN-GAME-CHECKLIST.md](IN-GAME-CHECKLIST.md).
