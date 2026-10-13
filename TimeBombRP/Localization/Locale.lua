local ADDON, ns = ...

local en = {
    TITLE="Time Bomb RP", SUBTITLE="A quiet table. A dangerous little game.",
    CREATE_TITLE="Open the game box", CREATE_HINT="Name your table, then invite 3–7 friends.",
    TABLE_NAME="Table name", DEFAULT_TABLE="The brass box", CREATE="Create table",
    DEMO4="Try · 4 seats", DEMO8="Preview · 8 seats", DEMO="DEMONSTRATION",
    DEMO_NEXT="Play a demo turn", DEMO_PERSPECTIVE="Change viewpoint",
    DEMO_HINT="Simulated table · no network messages", CLOSE="Close window", MINIMIZE="Minimize locally",
    RESTORE="Restore table", RULES="Rules", OPTIONS="Options", HISTORY="Public history", BACK="Back",
    RULESET="Immediate return forbidden", RULESET_SHORT="No immediate return",
    INVITE_NAME="Name-Realm", INVITE="Invite", INVITE_TARGET="Invite target",
    INVITE_TITLE="A seat at the table", INVITE_FROM="%s invites you", INVITE_SEATS="%s · %d / 8 seats",
    INVITE_COMPATIBLE="Compatible rules and version", INVITE_INCOMPATIBLE="Incompatible rules or version",
    INVITE_EXPLAIN="A game for 4–8 players. Your character's allegiance is unchanged.",
    ACCEPT="Accept", DECLINE="Decline", INVITATIONS="Invitations", NO_INVITATIONS="No invitations yet.",
    SENT="Sent", PENDING="Pending", ACCEPTED="Accepted", DECLINED="Declined", EXPIRED="Expired",
    INCOMPATIBLE="Incompatible", FULL="Table full", NO_RESPONSE="No response", FAILED="Unavailable",
    NO_RESPONSE_HINT="No response does not prove the addon is missing.",
    LOBBY="Gather around", LOBBY_HINT="4–8 accepted players, everyone ready.",
    SEATS="%d / 8 seats", EMPTY_SEAT="Available seat", HOST="Host", YOU="You", CONNECTED="Connected",
    DISCONNECTED="Waiting for connection", READY="Ready", NOT_READY="Not ready", SET_READY="I'm ready",
    UNREADY="I'm not ready", START="Deal the secrets", WAIT_HOST="Waiting for the host",
    READY_COUNT="%d / %d ready", JOINED="Joined", LEAVE="Leave table", CANCEL_GAME="Cancel game",
    LEAVE_TITLE="Leave this table?", LEAVE_BODY="During a game, leaving cancels it for everyone. Closing the window keeps your seat.",
    CANCEL_TITLE="Cancel this game?", CANCEL_BODY="The game will stop for everyone, without a winner or revealing secrets.",
    CONFIRM="Confirm", KEEP_PLAYING="Stay at the table", YES_LEAVE="Leave", YES_CANCEL="Cancel game",
    PROGRESS="Round %d/4  ·  Cuts %d/%d  ·  Defused %d/%d", PROGRESS_MINI="R%d · %d/%d",
    PREPARING="Dealing the secrets", PREPARING_HINT="Waiting for everyone's private information to arrive.",
    ACTIVE="Make your case", YOUR_TURN="Your turn", HOLDER="Pliers: %s", HOLDER_SHORT="%s holds the pliers",
    TURN_HINT="Select a hidden card, then confirm.", WAIT_TURN="Talk, listen… the pliers are with %s.",
    RETURN_FORBIDDEN="Immediate return forbidden: %s just passed you the pliers.",
    RETURN_PUBLIC="No immediate return to %s", RETURN_BADGE="No return", SELF_CARD="You cannot choose your own cards.",
    EMPTY_HAND="No hidden cards", OTHER_TURN="Only the player holding the pliers can cut.",
    REVEALED_CARD="Already revealed", CARD_INDEX="Card %d · %s", CARD_HIDDEN="Hidden cable",
    SELECTED="Selected", CHOOSE_CARD="Select a card", CUT="Cut at %s", WAITING="Waiting for confirmation…",
    REMAINING="%d hidden", BETWEEN_ROUNDS="Round complete", BETWEEN_HINT="Only unrevealed cables are shuffled again.",
    NEXT="Deal the next round", LAST_REVEAL="Last revelation", NO_REVEAL="The first cable is still hidden.",
    REVEAL_SUMMARY="%s → %s", SAFE="Safe cable", DEFUSE="Defusing cable", BOMB="Trapped cable",
    SAFE_SHORT="Safe", DEFUSE_SHORT="Defuse", BOMB_SHORT="Trap", DEFUSER="Defusers", SABOTEUR="Saboteurs",
    YOUR_ROLE="Your private team", PRIVATE_HINT="You know the contents, not the positions.",
    PRIVATE_EMPTY="Your secrets appear when the game starts.", PRIVATE_SYNC="Synchronizing private information…",
    PRIVATE_COUNTS="Safe %d   ·   Defuse %d   ·   Trap %d", PRIVATE_NONE="No hidden cables left in your hand.",
    GAME_OVER="Game over", WINNER="%s win", CANCELLED="Game cancelled", CANCELLED_HINT="No winner. Secrets remain private.",
    CAUSE_BOMB="The trapped cable was revealed.", CAUSE_DEFUSED="All defusing cables were found.",
    CAUSE_ROUNDS="Four rounds ended before the box was defused.", DISCARDED_ROLE="Undealt role: %s",
    REMATCH="Prepare a rematch", ROLE_REVEALED="Team revealed: %s", SUSPENDED="Game suspended",
    SUSPENDED_HINT="Waiting for connection. No card can be revealed.", RECOVERING="Restoring the table…",
    RECOVERING_HINT="Checking the saved revision with all players.", ONLINE="Whisper transport", OFFLINE="Transport unavailable",
    TRANSPORT_HINT="Direct addon whispers where supported. Same-realm, same-faction play is the first supported route.",
    NO_HISTORY="No public revelations yet.", HISTORY_ITEM="R%d · %s → %s · %s",
    EMOTE="Prepare an emote", EMOTE_HINT="A public fact only; edit and send the draft yourself.",
    OPTION_SOUND="Sound when it is my turn", OPTION_MOTION="Reduce animations", OPTION_EXPAND="Expand on my turn",
    OPTION_IGNORE="Ignore invitations", OPTION_SCALE="Window scale", SCALE_VALUE="%d%%", RESET_UI="Reset window position",
    OPTIONS_LOCAL="These settings apply only to your screen.", OPTIONS_RULE="The no-return rule is always enabled.",
    HELP_TEXT="Two secret teams compete around a miniature game box. Defusers win by finding all defusing cables; saboteurs win if the trapped cable is revealed, or if four rounds end first.\n\nYou know your team and the contents of your hand, but never the positions of your cards. Discuss, bargain and bluff freely.\n\nThe pliers holder chooses a hidden card belonging to another player. That player receives the pliers. After as many cuts as players, the host shuffles only the unrevealed cables and deals again. Hand sizes are 5, 4, 3, then 2.\n\nHouse rule: A → B → A is forbidden. B must choose another opponent. A → B → C → A is allowed. This restriction survives the next deal.\n\nNobody is eliminated, even with no cards left. There is no timer. Reducing or closing the window never leaves the table.\n\nThese are game roles, not your character's loyalties. No gold, items or public chat messages are involved.",
    NOTICE_GENERIC="The action could not be completed.", NOTICE_DETAIL="%s: %s", STATUS_IDLE="A game box for your roleplay table",
    ERROR_NAME="Enter a valid Name-Realm.", ERROR_TABLE_NAME="Choose a table name.", ERROR_NO_TARGET="Select a player to invite.",
    ERROR_BUSY="You are already at a table.", ERROR_NOT_HOST="Only the host can do that.", ERROR_NOT_READY="All players must be ready.",
    ERROR_CAPACITY="A table needs 4–8 players.", ERROR_PHASE="That action is unavailable at this stage.",
    ERROR_TURN="It is not your turn.", ERROR_SELF="You cannot choose your own cards.", ERROR_RETURN="Immediate return is forbidden.",
    ERROR_EMPTY="That player has no hidden cards.", ERROR_SLOT="That card is unavailable.", ERROR_STALE="The table changed. Select a card again.",
    ERROR_SUSPENDED="The game is suspended until connection is restored.", ERROR_INVITE="This invitation is no longer valid.",
    ERROR_FULL="This table is full.", ERROR_INCOMPATIBLE="Incompatible addon version or ruleset.",
    ERROR_TIMEOUT="No response yet. Delivery has not been confirmed.", ERROR_TRANSPORT="Addon whispers are currently unavailable.",
    ERROR_RECOVERY="Recovery cannot be confirmed. The host may cancel the table safely.", ERROR_NETWORK="A network message was rejected.",
    ERROR_WAIT="An action is already awaiting confirmation.", ERROR_DEMO_ACTIVE="Leave the current table before starting a demo.",
    INFO_INVITE_SENT="Invitation sent; waiting for an answer.", INFO_JOINED="Seat confirmed.", INFO_LEFT="You left the table.",
    INFO_DECLINED="Invitation declined.", INFO_CANCELLED="The table was cancelled.", INFO_READY="Readiness updated.",
}

en.EMOTE_TEXT="sets the ornate pliers beside %s after revealing a cable from the game box."
en.EMOTE_BUSY="Your chat box already contains text. Finish or clear it before preparing an emote."
en.EMOTE_UNAVAILABLE="No public revelation is available for an emote."
en.BUILD_MISMATCH="This addon targets Retail interface 120105. Your client build differs; compatibility needs checking."
en.WRONG_CLIENT="Time Bomb RP requires World of Warcraft Retail."
en.API_RESTRICTED="The client currently restricts outgoing addon whispers."
en.API_LOCKDOWN="Addon messages are temporarily locked by the client."
en.RATE_LIMIT="Please wait before inviting this player again."
en.INVALID_NAME="Enter a valid player name and realm."
en.JOIN_PENDING="Joining the table; waiting for host acknowledgement."
en.RECOVERY_DIVERGED="Recovery is suspended: a newer accepted revision was reported. The host can cancel the game."
en.INVALID_CHECKPOINT="The saved table cannot be restored safely."
en.NO_LEGAL_TARGET="The table is inconsistent: no legal target. The game must remain suspended."

local fr = {
    TITLE="Time Bomb RP", SUBTITLE="Une table tranquille. Un petit jeu dangereux.",
    CREATE_TITLE="Ouvrir le coffret", CREATE_HINT="Nommez votre table, puis invitez 3 à 7 amis.",
    TABLE_NAME="Nom de la table", DEFAULT_TABLE="Le coffret de laiton", CREATE="Créer une table",
    DEMO4="Essayer · 4 places", DEMO8="Aperçu · 8 places", DEMO="DÉMONSTRATION",
    DEMO_NEXT="Jouer un coup de démo", DEMO_PERSPECTIVE="Changer de point de vue",
    DEMO_HINT="Table simulée · aucun envoi réseau", CLOSE="Fermer la fenêtre", MINIMIZE="Réduire localement",
    RESTORE="Restaurer la table", RULES="Règles", OPTIONS="Options", HISTORY="Historique public", BACK="Retour",
    RULESET="Retour immédiat interdit", RULESET_SHORT="Retour immédiat interdit",
    INVITE_NAME="Nom-Royaume", INVITE="Inviter", INVITE_TARGET="Inviter la cible",
    INVITE_TITLE="Une place à la table", INVITE_FROM="%s vous invite", INVITE_SEATS="%s · %d / 8 places",
    INVITE_COMPATIBLE="Version et règles compatibles", INVITE_INCOMPATIBLE="Version ou règles incompatibles",
    INVITE_EXPLAIN="Un jeu pour 4 à 8 personnes, sans imposer de camp à votre personnage.",
    ACCEPT="Accepter", DECLINE="Refuser", INVITATIONS="Invitations", NO_INVITATIONS="Aucune invitation pour le moment.",
    SENT="Envoyée", PENDING="En attente", ACCEPTED="Acceptée", DECLINED="Refusée", EXPIRED="Expirée",
    INCOMPATIBLE="Incompatible", FULL="Table complète", NO_RESPONSE="Sans réponse", FAILED="Indisponible",
    NO_RESPONSE_HINT="L'absence de réponse ne prouve pas l'absence de l'addon.",
    LOBBY="Prenez place", LOBBY_HINT="4 à 8 participants acceptés, tous prêts.",
    SEATS="%d / 8 places", EMPTY_SEAT="Place disponible", HOST="Hôte", YOU="Vous", CONNECTED="Connecté",
    DISCONNECTED="Attente de connexion", READY="Prêt", NOT_READY="Pas prêt", SET_READY="Je suis prêt",
    UNREADY="Je ne suis plus prêt", START="Distribuer les secrets", WAIT_HOST="En attente de l'hôte",
    READY_COUNT="%d / %d prêts", JOINED="À table", LEAVE="Quitter la table", CANCEL_GAME="Annuler la partie",
    LEAVE_TITLE="Quitter cette table ?", LEAVE_BODY="En cours de partie, votre départ l'annule pour tous. Fermer la fenêtre conserve votre place.",
    CANCEL_TITLE="Annuler cette partie ?", CANCEL_BODY="La partie s'arrêtera pour tous, sans victoire et sans révéler les secrets.",
    CONFIRM="Confirmer", KEEP_PLAYING="Rester à table", YES_LEAVE="Quitter", YES_CANCEL="Annuler la partie",
    PROGRESS="Manche %d/4  ·  Coupes %d/%d  ·  Désamorçages %d/%d", PROGRESS_MINI="M%d · %d/%d",
    PREPARING="Distribution des secrets", PREPARING_HINT="En attente de la réception des informations privées de chacun.",
    ACTIVE="À vous de convaincre", YOUR_TURN="À vous", HOLDER="Pince : %s", HOLDER_SHORT="%s tient la pince",
    TURN_HINT="Choisissez une carte cachée, puis confirmez.", WAIT_TURN="Discutez, écoutez… %s tient la pince.",
    RETURN_FORBIDDEN="Retour immédiat interdit : %s vient de vous donner la pince.",
    RETURN_PUBLIC="Retour interdit vers %s", RETURN_BADGE="Retour interdit", SELF_CARD="Vous ne pouvez pas choisir vos propres cartes.",
    EMPTY_HAND="Aucune carte cachée", OTHER_TURN="Seul le détenteur de la pince peut couper.",
    REVEALED_CARD="Déjà révélée", CARD_INDEX="Carte %d · %s", CARD_HIDDEN="Câble caché",
    SELECTED="Sélectionnée", CHOOSE_CARD="Choisissez une carte", CUT="Couper chez %s", WAITING="En attente de confirmation…",
    REMAINING="%d cachée(s)", BETWEEN_ROUNDS="Manche terminée", BETWEEN_HINT="Seules les cartes non révélées seront remélangées.",
    NEXT="Distribuer la manche suivante", LAST_REVEAL="Dernière révélation", NO_REVEAL="Le premier câble attend encore.",
    REVEAL_SUMMARY="%s → %s", SAFE="Câble neutre", DEFUSE="Câble désamorçant", BOMB="Câble piégé",
    SAFE_SHORT="Neutre", DEFUSE_SHORT="Désamorçant", BOMB_SHORT="Piège", DEFUSER="Désamorceurs", SABOTEUR="Saboteurs",
    YOUR_ROLE="Votre camp privé", PRIVATE_HINT="Vous connaissez le contenu, pas la position des cartes.",
    PRIVATE_EMPTY="Vos secrets apparaîtront au début de la partie.", PRIVATE_SYNC="Synchronisation des informations privées…",
    PRIVATE_COUNTS="Neutres %d   ·   Désamorçants %d   ·   Piège %d", PRIVATE_NONE="Il ne vous reste aucune carte cachée.",
    GAME_OVER="Partie terminée", WINNER="Victoire des %s", CANCELLED="Partie annulée", CANCELLED_HINT="Aucun vainqueur. Les secrets restent privés.",
    CAUSE_BOMB="Le câble piégé a été révélé.", CAUSE_DEFUSED="Tous les câbles désamorçants ont été trouvés.",
    CAUSE_ROUNDS="Quatre manches écoulées sans désamorçage.", DISCARDED_ROLE="Rôle écarté : %s",
    REMATCH="Préparer une revanche", ROLE_REVEALED="Camp révélé : %s", SUSPENDED="Partie suspendue",
    SUSPENDED_HINT="En attente de connexion. Aucune carte ne peut être révélée.", RECOVERING="Restauration de la table…",
    RECOVERING_HINT="Vérification de la version sauvegardée auprès des participants.", ONLINE="Messages privés addon", OFFLINE="Transport indisponible",
    TRANSPORT_HINT="Messages addon ciblés lorsque le client le permet. Le premier cas pris en charge est même royaume, même faction.",
    NO_HISTORY="Aucune révélation publique pour le moment.", HISTORY_ITEM="M%d · %s → %s · %s",
    EMOTE="Préparer une emote", EMOTE_HINT="Un fait public uniquement ; modifiez et envoyez vous-même le brouillon.",
    OPTION_SOUND="Son lorsque c'est mon tour", OPTION_MOTION="Réduire les animations", OPTION_EXPAND="Déployer à mon tour",
    OPTION_IGNORE="Ignorer les invitations", OPTION_SCALE="Échelle de la fenêtre", SCALE_VALUE="%d %%", RESET_UI="Réinitialiser la position",
    OPTIONS_LOCAL="Ces réglages ne concernent que votre écran.", OPTIONS_RULE="La règle anti-retour est toujours active.",
    HELP_TEXT="Deux camps secrets s'affrontent autour d'un coffret de jeu miniature. Les Désamorceurs gagnent en trouvant tous les câbles désamorçants ; les Saboteurs gagnent si le câble piégé est révélé, ou après quatre manches inachevées.\n\nVous connaissez votre camp et le contenu de votre main, jamais la position de vos cartes. Discutez, négociez et bluffez librement.\n\nLe détenteur de la pince choisit une carte cachée chez un adversaire. Celui-ci reçoit la pince. Après autant de coupes que de joueurs, l'hôte remélange uniquement les cartes non révélées. Les mains comptent successivement 5, 4, 3 puis 2 cartes.\n\nVariante maison : A → B → A est interdit. B doit choisir un autre adversaire. A → B → C → A est autorisé. L'interdiction reste active après une redistribution.\n\nPersonne n'est éliminé, même sans carte. Aucun chronomètre. Réduire ou fermer la fenêtre ne quitte jamais la table.\n\nCes camps sont des rôles de jeu, pas des allégeances imposées aux personnages. Ni or, ni objet, ni message public automatique.",
    NOTICE_GENERIC="Cette action n'a pas pu aboutir.", NOTICE_DETAIL="%s : %s", STATUS_IDLE="Un coffret de jeu pour votre table RP",
    ERROR_NAME="Saisissez un Nom-Royaume valide.", ERROR_TABLE_NAME="Choisissez un nom de table.", ERROR_NO_TARGET="Ciblez un joueur à inviter.",
    ERROR_BUSY="Vous êtes déjà à une table.", ERROR_NOT_HOST="Seul l'hôte peut effectuer cette action.", ERROR_NOT_READY="Tous les participants doivent être prêts.",
    ERROR_CAPACITY="Une table doit réunir 4 à 8 joueurs.", ERROR_PHASE="Cette action n'est pas disponible à cette étape.",
    ERROR_TURN="Ce n'est pas votre tour.", ERROR_SELF="Vous ne pouvez pas choisir vos propres cartes.", ERROR_RETURN="Le retour immédiat est interdit.",
    ERROR_EMPTY="Ce joueur n'a plus de carte cachée.", ERROR_SLOT="Cette carte n'est plus disponible.", ERROR_STALE="La table a changé. Sélectionnez à nouveau une carte.",
    ERROR_SUSPENDED="La partie est suspendue jusqu'au rétablissement de la connexion.", ERROR_INVITE="Cette invitation n'est plus valable.",
    ERROR_FULL="Cette table est complète.", ERROR_INCOMPATIBLE="Version de l'addon ou règles incompatibles.",
    ERROR_TIMEOUT="Sans réponse pour le moment. La réception n'est pas confirmée.", ERROR_TRANSPORT="Les messages privés addon sont indisponibles pour le moment.",
    ERROR_RECOVERY="La reprise ne peut pas être confirmée. L'hôte peut annuler proprement la table.", ERROR_NETWORK="Un message réseau a été rejeté.",
    ERROR_WAIT="Une action attend déjà sa confirmation.", ERROR_DEMO_ACTIVE="Quittez la table actuelle avant de démarrer une démo.",
    INFO_INVITE_SENT="Invitation envoyée ; en attente d'une réponse.", INFO_JOINED="Votre place est confirmée.", INFO_LEFT="Vous avez quitté la table.",
    INFO_DECLINED="Invitation refusée.", INFO_CANCELLED="La table a été annulée.", INFO_READY="État Prêt mis à jour.",
}

fr.EMOTE_TEXT="pose la pince ouvragée près de %s après avoir révélé un câble du coffret de jeu."
fr.EMOTE_BUSY="Le champ de discussion contient déjà du texte. Terminez-le ou effacez-le avant de préparer une emote."
fr.EMOTE_UNAVAILABLE="Aucune révélation publique ne permet encore de préparer une emote."
fr.BUILD_MISMATCH="Cet addon cible l'interface Retail 120105. Votre client diffère ; sa compatibilité reste à vérifier."
fr.WRONG_CLIENT="Time Bomb RP nécessite World of Warcraft Retail."
fr.API_RESTRICTED="Le client restreint actuellement les messages privés addon sortants."
fr.API_LOCKDOWN="Le client bloque temporairement les messages addon."
fr.RATE_LIMIT="Patientez avant de solliciter à nouveau ce joueur."
fr.INVALID_NAME="Saisissez un nom de joueur et un royaume valides."
fr.JOIN_PENDING="Adhésion en cours ; en attente de confirmation de l'hôte."
fr.RECOVERY_DIVERGED="Reprise suspendue : un état plus récent a déjà été accepté. L'hôte peut annuler la partie."
fr.INVALID_CHECKPOINT="La table sauvegardée ne peut pas être restaurée de façon fiable."
fr.NO_LEGAL_TARGET="État incohérent : aucune cible légale. La partie doit rester suspendue."

en.CHECKPOINT_EXPIRED="The saved table is over 12 hours old. Its private recovery data has been discarded."
fr.CHECKPOINT_EXPIRED="La table sauvegardée date de plus de 12 heures. Ses données privées de reprise ont été effacées."

ns.L = setmetatable({}, { __index = function(_, key)
    if GetLocale and GetLocale() == "frFR" and fr[key] ~= nil then return fr[key] end
    return en[key] or key
end })
ns.LocaleEnglish = en
