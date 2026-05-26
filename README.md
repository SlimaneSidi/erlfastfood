# ErlFastFood

Projet fast-food en Erlang

#### Membres : Mathis MESSINGUIRAL, Ange Vanessa MANDJEU SAPPELLE, Roche Kevin EKO'O MEKULU, Robin NULLANS.

## Modules

| Module        | Rôle                                                              |
| ------------- | ----------------------------------------------------------------- |
| `ffserver`    | Serveur (la « cuisine »). Reçoit les messages, persiste en BDD.   |
| `ffclient`    | Client texte (console).                                           |
| `ffui`        | Client graphique wxWidgets.                                       |
| `ffdb`        | Couche d'accès à la BDD Mnesia (catalogue + historique commandes).|
| `ffdb.hrl`    | Records partagés `#commande{}` et `#menu_item{}`.                 |

## Option 1 : Test local

    c(ffdb).
    c(ffserver).
    c(ffclient).
    c(ffui).
    ffdb:install().            %% UNE SEULE FOIS : crée le schéma Mnesia sur disque
    ffserver:start_local().

Pour utiliser l'interface graphique au lieu du client console, dans un **second** shell Erlang :

    c(ffui).
    ffui:start().

## Option 2 : Mode réseau

### Coté Serveur (IP ex : 192.168.1.10)

    erl -name serveur@192.168.1.10 -setcookie test

    c(ffdb).
    c(ffserver).
    c(ffclient).
    ffdb:install().            %% UNE SEULE FOIS sur le poste serveur
    ffserver:start().

### Coté Client console (IP ex : 192.168.1.20)

    erl -name client1@192.168.1.20 -setcookie test

    c(ffclient).
    ffclient:client({erlfastfood, 'serveur@192.168.1.10'}, []).

### Coté Client UI (IP ex : 192.168.1.20)

    erl -name client1@192.168.1.20 -setcookie test

    c(ffui).
    ffui:start({erlfastfood, 'serveur@192.168.1.10'}).

## Base de données Mnesia

La BDD Mnesia stocke deux choses, en `disc_copies` (persistant entre redémarrages) :

- **`menu_item`** : le catalogue (ingrédients burger, boissons, tailles frites + prix).
  Auto-rempli au premier `ffdb:install()`.
- **`commande`** : l'historique des commandes validées
  `{id, timestamp, client, items, total}`.
  Une nouvelle ligne est écrite à chaque fois qu'un client envoie `fin`
  (bouton « Valider et quitter » côté UI, ou choix 5 côté client texte).

### Installation (la première fois seulement)

Sur le poste **serveur** :

    c(ffdb).
    ffdb:install().

Ça crée un dossier `Mnesia.serveur@...` à côté des `.beam` qui contient la BDD sur disque. Le serveur la rouvrira automatiquement à chaque démarrage suivant.

### Commandes utiles dans le shell du serveur

    ffserver:afficher_historique().    %% Joli affichage des commandes passées
    ffdb:list_commandes().             %% Liste brute des records #commande{}
    ffdb:get_commande(1).              %% Récupère une commande par son ID
    ffdb:clear_commandes().            %% Vide l'historique (garde le menu)
    ffdb:list_menu(boisson).           %% Catalogue des boissons
    ffdb:list_menu(burger_ingredient). %% Catalogue des ingrédients burger
    ffdb:list_menu(frites).            %% Catalogue des tailles de frites

### Vérifier la persistance

1. Passer quelques commandes depuis un (ou plusieurs) clients, puis `Valider`.
2. Sur le serveur : `ffserver:afficher_historique().` — les commandes apparaissent.
3. Tuer le serveur (`Ctrl-C` `Ctrl-C`), relancer le BEAM, faire `ffserver:start()` puis
   à nouveau `ffserver:afficher_historique()` : **les commandes sont toujours là**.

## ATTENTION

- Les **cookies** doivent être identiques pour le serveur et tous les clients (ici `test`).
- En cas de problème, vérifier la connexion depuis le client avec `net_adm:ping('serveur@192.168.1.10').` qui doit retourner `pong`. Si `pang` → cookie, nom de nœud, ou firewall (EPMD port 4369).
- `-sname` (nom court) sans `@` n'accepte **pas** d'IP. Pour une IP, utiliser `-name nom@IP`.
- Lancer `ffdb:install()` **uniquement sur le poste serveur** (c'est lui qui héberge la BDD).
