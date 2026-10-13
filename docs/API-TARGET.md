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

## Total RP 3 et animations (1.1.0)

Sources TRP3 consultées : [Total-RP/Total-RP-3, commit f0f6ab7](https://github.com/Total-RP/Total-RP-3/tree/f0f6ab7767d8d324c1b14519ed3b383b41ec0675).

- `Modules/Register/Characters/RegisterMain.lua` : `TRP3_API.register.getCharacterList()` et `getUnitRPNameWithID(unitID, fallback)`. Une table locale réconcilie la casse des identités canoniques avec celle du registre TRP. Aucun accès direct aux SavedVariables de TRP3.
- `Core/Profiles.lua` : `getPlayerCurrentProfile()` permet d'attendre le chargement du profil local.
- `Core/Objects/Callback.lua` et `Core/Events.lua` : `RegisterCallback` sur `REGISTER_DATA_UPDATED`, `REGISTER_PROFILES_LOADED`, `WORKFLOW_ON_LOADED` ; invalidation du cache et actualisation de l'UI. TRP3 reste facultatif.
- `SimpleAnimScaleAPIDocumentation.lua` du miroir Blizzard : `SetScaleFrom(x,y)`, `SetScaleTo(x,y)`, `SetOrigin(point,x,y)`. Les anciennes méthodes de scale ne sont pas utilisées.
- `ChatInfoDocumentation.lua` : `C_ChatInfo.SendChatMessage(message, 'EMOTE')`, API avec restrictions, sans confirmation de livraison. `InChatMessagingLockdown()` est contrôlé avant l'envoi. Les emotes publiques sont distinctes du transport des états privés ; aucune donnée privée n'y transite.

Le rendu des noms dans le chat et les envois d'emotes restent à tester dans le client Retail réel. Les tests automatisés exercent un double d'API, pas le chat WoW.
