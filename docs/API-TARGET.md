# Cible Retail et preuves consultées

Vérification effectuée le **13 octobre 2026**. Aucun client WoW n'est installé dans l'environnement de développement.

Le miroir des sources Blizzard [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) sur la branche `live` identifie le client **12.1.5 (70340)**. Commit consulté : [`7b27d6845ca49ecb713d49f49c22d9f0fb43f3e4`](https://github.com/Gethe/wow-ui-source/commit/7b27d6845ca49ecb713d49f49c22d9f0fb43f3e4), daté du 13 octobre 2026. `version.txt` vaut `12.1.5.70340`. Le TOC cible donc **120105**, et non l'ancienne valeur 120100. Le client réellement installé chez le joueur reste à vérifier : `/dump GetBuildInfo()`.

Sources vérifiées dans ce commit :

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua`
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua`
- `Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua`

## Communication

`C_ChatInfo.RegisterAddonMessagePrefix(prefix)` renvoie une énumération : Success=0, DuplicatePrefix=1, InvalidPrefix=2, MaxPrefixes=3. Le code accepte explicitement 0/1. Un nombre non nul n'est pas assimilé à `true`.

`C_ChatInfo.SendAddonMessage(prefix,message,chatType,target)` renvoie :

| Code | Nom |
|---:|---|
| 0 | Success |
| 1 | InvalidPrefix |
| 2 | InvalidMessage |
| 3 | AddonMessageThrottle |
| 4 | InvalidChatType |
| 5 | NotInGroup |
| 6 | TargetRequired |
| 7 | InvalidChannel |
| 8 | ChannelThrottle |
| 9 | GeneralError |
| 10 | NotInGuild |
| 11 | AddOnMessageLockdown |
| 12 | TargetOffline |

L'addon utilise uniquement le canal ciblé `WHISPER`, préfixe `TBRP1`, avec fragmentation bornée. Un succès local ne constitue pas une réception distante ; adhésions, intentions et présence disposent de confirmations applicatives. Les champs expéditeur des données ne font jamais autorité : l'identité est celle de `CHAT_MSG_ADDON(prefix,text,channel,sender,target,...)`.

`AreOutgoingAddonChatMessagesRestricted()` expose une restriction définie par royaume, indépendamment des restrictions de réception. `InChatMessagingLockdown()` expose le verrouillage des communications. L'adaptateur arrête l'envoi si l'une de ces conditions s'applique et montre un état d'indisponibilité. **L'addon ne peut pas garantir que le multijoueur est autorisé sur tous les royaumes Retail.** Aucun contournement ni repli vers le chat public n'est prévu.

Le premier test réel à effectuer est quatre joueurs **non groupés, même royaume, même faction**, avec les restrictions désactivées par le client. La compatibilité inter-royaumes/factions n'est pas promise. Les sources API vérifient une signature ; elles ne prouvent pas le routage réel.

## Présentation

Frames, FontStrings, textures et animations natives. `SetFont` reçoit toujours un chemin chaîne, une taille numérique et des flags chaîne (dont `''`). Les TGA sont livrées sans compression, RGBA 32 bits, dimensions puissances de deux. Leurs en-têtes et pixels sont contrôlés hors jeu ; le rendu exact du client reste dans la checklist manuelle.
