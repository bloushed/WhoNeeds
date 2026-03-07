# WhoNeeds

Addon WoW Retail oriente raid qui observe `ENCOUNTER_LOOT_RECEIVED`, calcule si un item de boss est interessant pour la specialisation active et affiche les joueurs du groupe a qui l'objet semble convenir.

## Ce que fait cette version

- Detecte les loots de boss.
- Verifie si l'item est equipable par le joueur local.
- Rejette les pieces d'armure qui ne correspondent pas a l'armure principale de la classe.
- Score l'objet avec l'ilvl et les stats secondaires pour la spe active.
- Compare ce score avec l'equipement actuellement porte.
- Marque un item en `BiS` si son `itemID` est enregistre pour la spe active.
- Partage les interets des joueurs ayant aussi l'addon via `CHAT_MSG_ADDON`.
- Affiche une fenetre avec le loot, les joueurs interesses et un bouton `Ask` qui envoie `Do you need it?` au looteur.
- Peut charger des priorites de stats et listes BiS depuis un addon compagnon `WhoNeeds_Data`.

## Limites importantes

- Pour voir la liste complete des joueurs interesses, il faut que les autres membres aient aussi l'addon.
- Les poids de stats par defaut sont generiques par role/categorie de spe. Ce n'est pas encore une base BiS complete par classe/spe.
- Sans `WhoNeeds_Data`, l'addon fonctionne en mode fallback avec des poids generiques. Un message explique au login comment installer le pack de donnees.
- Les objets tres particuliers (trinkets a proc, effets uniques, armes avec logique speciale) ne sont pas encore evalues finement.
- La cle de regroupement des loots est simple. Deux items strictement identiques lootes par le meme joueur sur le meme boss peuvent se fusionner dans l'affichage.

## Commandes

- `/whoneeds` : affiche ou masque la fenetre.
- `/whoneeds data` : affiche l'etat du pack de donnees.
- `/whoneeds msg <texte>` : change le message envoye par le bouton `Ask`.
- `/whoneeds bis add <itemID>` : ajoute un item a la liste BiS de la spe actuelle.
- `/whoneeds bis remove <itemID>` : retire un item de la liste BiS de la spe actuelle.

## Installation

1. Copier le dossier `WhoNeeds` dans `World of Warcraft\_retail_\Interface\AddOns\`.
2. Copier le dossier `WhoNeeds_Data` au meme endroit si tu veux les priorites de stats et BiS packages.
3. Verifier que chaque dossier contient bien son fichier `.toc` a la racine.
4. Lancer le jeu puis activer les addons.

## Structure du depot

```text
INeedIt/
|- WhoNeeds/
|  |- WhoNeeds.toc
|  |- Data.lua
|  |- Analyzer.lua
|  |- UI.lua
|  `- Core.lua
|- WhoNeeds_Data/
|  |- WhoNeeds_Data.toc
|  `- WhoNeeds_Data.lua
`- scripts/
   |- generate_whoneeds_data.py
   `- update_whoneeds_data.cmd
```

## Separation code / donnees

- `WhoNeeds` contient la logique de scan, de scoring, l'UI et la communication de groupe.
- `WhoNeeds_Data` contient les priorites de stats et les listes BiS.
- Si `WhoNeeds_Data` manque, `WhoNeeds` affiche un message explicatif et continue en mode fallback.

## D'ou viennent les donnees

- Les priorites de stats et les listes BiS de `WhoNeeds_Data` sont generees automatiquement depuis `murlok.io`.
- Le script `scripts/generate_whoneeds_data.py` visite les pages PvE de chaque spe, extrait les priorites de stats secondaires et les items de gear, puis reecrit `WhoNeeds_Data/WhoNeeds_Data.lua`.
- Le fichier genere expose ces donnees dans `_G.WhoNeedsExternalData`.
- La metadonnee `source` du pack genere vaut actuellement `murlok.io live scrape`.

Schema simplifie :

```text
murlok.io
   |
   v
scripts/generate_whoneeds_data.py
   |
   v
WhoNeeds_Data/WhoNeeds_Data.lua
   |
   v
_G.WhoNeedsExternalData
   |
   v
WhoNeeds charge les donnees au login
```

En pratique :

- `WhoNeeds` charge `_G.WhoNeedsExternalData` au login.
- Si le pack est present, les donnees par spe ecrasent les poids generiques de base.
- Si le pack est absent, l'addon reste utilisable avec des poids fallback plus simples.

## Comment les priorites de stats sont choisies

Le systeme fonctionne en 3 couches :

1. Une base generique par grande famille de spe :
   - `TANK`
   - `HEALER`
   - `CASTER`
   - `RANGED`
   - `MELEE`
2. Une surcharge optionnelle venant de `WhoNeeds_Data` pour la spe exacte.
3. Une surcharge locale optionnelle depuis la base sauvegardee (`WhoNeedsDB`) si tu modifies manuellement des poids.

La stat principale utilisee est detectee automatiquement depuis la spe active :

- `STRENGTH`
- `AGILITY`
- `INTELLECT`

Donc, pour une spe donnee, l'addon construit des `weights` finaux en partant d'un profil generique, puis en appliquant les donnees specifiques de la spe si elles existent.

## Comment le score est calcule

Chaque item recoit un score numerique. Ce score sert uniquement a comparer l'objet loote a ton equipement actuel.

Schema simplifie :

```text
Spe active
   |
   +--> role/categorie -> poids generiques
   |
   +--> WhoNeeds_Data -> surcharge de poids par spe
   |
   +--> DB locale -> surcharge manuelle eventuelle
   |
   v
weights finaux

Item loot
   |
   +--> item level
   |
   +--> stats (main stat, stamina, haste, mastery, crit, vers)
   |
   v
score item = (ilvl * poids_ILVL) + (stats_ponderees / 12)
```

Formule :

```text
score = (itemLevel * poids_ILVL) + (somme_des_stats_ponderees / 12)
```

La somme des stats ponderees inclut :

- la stat principale (`Strength`, `Agility` ou `Intellect`)
- `Stamina`
- `Haste`
- `Mastery`
- `Crit`
- `Vers`

Exemple conceptuel :

- si une spe prefere `Haste` a `Crit`, alors 100 Haste rapporteront plus de score que 100 Crit.
- l'`item level` garde un poids important, donc un objet plus haut ilvl monte vite dans le classement.

Le diviseur `/ 12` sert simplement a garder la contribution des stats dans une echelle raisonnable par rapport a l'ilvl.

## Comment l'addon decide BiS / Upgrade / Sidegrade / Pass

Une fois le score calcule :

1. L'addon verifie d'abord si l'item est equipable par la classe et si l'armure correspond bien au type principal de la classe.
2. Il identifie le slot a remplacer.
3. Il compare le score du loot au score de l'objet actuellement equipe dans ce slot.
4. Il calcule `delta = score_nouveau - score_actuel`.

Le resultat affiche suit cette logique :

- `BiS` : l'`itemID` est present dans la liste BiS de la spe active.
- `Upgrade` : il n'y a rien equipe dans le slot, ou `delta >= majorUpgrade`.
- `Sidegrade` : `delta >= minUpgrade`.
- `Pass` : sinon.

Par defaut :

- `minUpgrade = 3`
- `majorUpgrade = 12`

Ces seuils sont stockes dans la configuration et peuvent etre ajustes.

Schema simplifie :

```text
Item loot
   |
   +--> equipable ? non -> PASS
   |
   +--> oui
          |
          +--> item dans la liste BiS de la spe ? oui -> BIS
          |
          +--> non
                 |
                 +--> calcul du score du loot
                 +--> calcul du score de l'item equipe
                 +--> delta = nouveau - actuel
                 |
                 +--> delta >= majorUpgrade -> UPGRADE
                 +--> delta >= minUpgrade   -> SIDEGRADE
                 +--> sinon                 -> PASS
```

## Cas particuliers pris en compte

- Anneaux, bijoux et armes a une main : l'addon compare contre le moins bon des deux slots concernes.
- Arme 2M : l'addon compare contre la somme du score main main + off hand actuellement equipes.
- Si l'objet n'est pas equipable, il est classe `Pass` avec une raison explicite.

## Limites du score

- Le score est un heuristique simple, pas une simulation.
- Les trinkets a proc, effets uniques, bonus de set, embellishments, armes speciales et interactions de talents ne sont pas modelises finement.
- Une liste `BiS` peut forcer l'etat `BiS` meme si la formule de score brute ne rend pas l'objet visiblement superieur.
- Les donnees `murlok.io` representent une source externe orientee meta, pas une verite absolue pour tous les joueurs.

## Regeneration automatique des donnees

- Le script `scripts/generate_whoneeds_data.py` recupere automatiquement les priorites de stats et les items BiS depuis `murlok.io`.
- Il decouvre les spes tout seul, telecharge les pages PvE, puis reecrit `WhoNeeds_Data/WhoNeeds_Data.lua`.
- Tu peux le lancer directement avec Python :

```powershell
python scripts/generate_whoneeds_data.py
```

- Ou via le lanceur Windows :

```powershell
scripts\update_whoneeds_data.cmd
```

- Pour generer les donnees raid au lieu de Mythic+ :

```powershell
scripts\update_whoneeds_data.cmd --content raid
```

- Pour tester une seule spe :

```powershell
python scripts/generate_whoneeds_data.py --spec paladin/protection --stdout
```

- La source actuelle du pack genere est `murlok.io`, et le fichier produit contient `updatedAt`, `contentType` et `season`.

## Pistes pour la suite

- Ajouter une vraie configuration en UI pour les stat weights par spe.
- Importer des listes BiS par saison et par specialisation.
- Gerer des templates de whisper differents selon le contexte.
- Afficher l'emplacement remplace et la difference exacte de score dans l'interface.
