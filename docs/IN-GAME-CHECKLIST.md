# Recette native — à exécuter, aucun résultat présumé

Cette checklist nécessite quatre vrais clients Retail. Tous installent la même version. Activer les erreurs Lua (`/console scriptErrors 1`). Relever `/dump GetBuildInfo()` et les deux indicateurs de restriction de C_ChatInfo. Ces essais n'ont pas été effectués dans l'environnement de développement.

- [ ] Quatre personnages non groupés, même royaume, même faction. L'addon se charge sans erreur, les TGA ont alpha/orientation corrects, les accents sont lisibles.
- [ ] Créer une table nommée ; inviter par nom et par cible. Vérifier l'identité réelle, le nombre de places et « Retour immédiat interdit » sur l'invitation.
- [ ] Refuser, ignorer, laisser expirer, retenter après cooldown. Une absence de réponse ne doit pas affirmer que l'addon manque. Aucune invitation de groupe WoW.
- [ ] Accepter simultanément la dernière place d'une table à huit. Un seul siège est attribué. Vérifier versions/ruleset incompatibles.
- [ ] Tous cliquent Prêt ; l'hôte démarre. Chaque personne voit son camp et le contenu de sa main regroupé par type, jamais les positions cachées. Les comptes diminuent après une coupe chez elle.
- [ ] Discuter aussi longtemps que souhaité ; aucun chronomètre de décision ni bouton de déclaration requis.
- [ ] Le détenteur sélectionne une carte puis modifie sa sélection avant confirmation. Aucune révélation ou transmission de pince avant réponse de l'hôte.
- [ ] A coupe chez B : B ne peut choisir A ; B choisit C ; C peut choisir A, mais pas B. Vérifier le texte explicatif et le symbole non accusatoire.
- [ ] Réduire/fermer la fenêtre sur un client. Les autres ne bougent pas, le chat continue, la barre indique la pince. Restaurer affiche l'état courant.
- [ ] Fin de manche : résultat public uniquement, hôte redistribue, mains plus petites, rôles inchangés, compte conservé. Le précédent détenteur reste interdit.
- [ ] `/reload` sur le détenteur : même siège, rôles, slots, comptes et interdiction ; pas de nouvelle action automatique.
- [ ] `/reload` sur l'hôte : reprise suspendue puis rapprochement avec les révisions clients ; aucun remélange ni retour sur une coupe connue.
- [ ] Couper temporairement la connexion d'un participant. Délai de grâce, suspension, reconnexion puis reprise ; aucune action automatique ni défaite.
- [ ] Départ volontaire confirmé pendant la partie : annulation, aucun camp vainqueur, pas de révélation des secrets restants.
- [ ] Gagner par désamorçage / bombe / quatre manches. Les rôles de fin et la cause sont justes. Revanche : nouveau jeu, nouvelles préparations, aucune vieille intention réappliquée.
- [ ] Options : sons désactivés, mouvement réduit, échelle, invitations ignorées, expansion locale facultative ; aucun focus clavier volé.
- [ ] Noms longs et accentués, huit places, main vide, tiroir d'historique, main personnelle lisible à différentes échelles.
- [ ] Survol des cartes adverses : zoom et fondu fluides, dos inchangé tant que caché, face correcte si publique, clic toujours fonctionnel. Sortie rapide, changement de carte, réduction et redistribution ne laissent aucun aperçu orphelin. Mouvement réduit : zoom instantané.
- [ ] TRP3 présent/absent, profils connus/inconnus, changement de profil local/distant : nom RP actualisé, vraie identité au survol, invitations inchangées.
- [ ] Emotes activées : une seule ligne publique par coupe confirmée, envoyée par son auteur, cible RP correcte et résultat vrai/faux fil/bombe. Rien sur sélection seule, coupe refusée, démo ou `/reload`. Le champ de discussion déjà saisi reste intact.
- [ ] Désactiver les emotes : aucun envoi sur ses propres coupes. Réactiver sans rejouer le passé. Chat verrouillé : notice locale et aucun envoi différé après déverrouillage.
- [ ] `/tb demo` et `/tb demo 8` : mode annoncé, perspectives limitées séparées, aucune émission réseau réelle, aucun checkpoint live remplacé.
- [ ] Session fermée : absence de trafic périodique, anciennes invitations inopérantes, informations privées nettoyées.

En cas de blocage de communication, relever le code public et le build ; ne pas exporter les SavedVariables secrets de l'hôte.
