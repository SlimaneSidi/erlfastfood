# 🍔 Projet ErlFastFood - Version Distribuée

Ce projet est un système de commande de fast-food simple écrit en Erlang. Cette version permet de faire tourner le serveur sur une machine et de passer commande depuis une autre machine sur le même réseau.

## 📋 Modifications apportées pour le réseau

1.  **Enregistrement du processus** : Le serveur s'enregistre désormais sous le nom `la_cuisine`. Cela permet au client de le contacter via son nom plutôt que par son PID (qui change à chaque lancement).
2.  **Mode Réseau** : Ajout d'une fonction `ffserver:start_remote/0` pour lancer la cuisine seule.
3.  **Communication Distribuée** : Le client peut maintenant prendre un nom de nœud (ex: `serveur@192.168.1.10`) pour envoyer les messages à travers le réseau.

---

## 💻 Code Complet du Serveur (`FFServer.erl`)

```erlang
-module(ffserver).
-export([start/0, start_remote/0, loop_serveur/0]).

%% Lance le serveur et un client local (test sur une seule machine)
start() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte (Local) ! ===~n"),
    ServerPid = spawn(?MODULE, loop_serveur, []),
    register(la_cuisine, ServerPid),
    ffclient:client(la_cuisine, []).

%% Lance le serveur seul pour les connexions réseaux
start_remote() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte (Réseau) ! ===~n"),
    ServerPid = spawn(?MODULE, loop_serveur, []),
    register(la_cuisine, ServerPid),
    io:format("En attente de clients sur le nœud : ~p~n", [node()]).

loop_serveur() ->
    receive
        {_From, burger} ->
            io:format("CUISINE : Burger en préparation... prêt !~n"),
            loop_serveur();
        {_From, frites} ->
            io:format("CUISINE : Frites en préparation... prêtes !~n"),
            loop_serveur();
        {_From, boisson} ->
            io:format("CUISINE : Boisson en préparation... prête !~n"),
            loop_serveur();
        {_From, {recap, Liste}} ->
            io:format("CUISINE : Récapitulatif : ~p~n", [Liste]),
            loop_serveur();
        {_From, {supprimer, Article}} ->
            io:format("CUISINE : Article ~p annulé.~n", [Article]),
            loop_serveur();
        {_From, fin} ->
            io:format("CUISINE : Commande terminée. Bonne dégustation !~n")
    end.
```

---

## 📱 Code Complet du Client (`FFClient.erl`)

```erlang
-module(ffclient).
-export([client/2, afficher_menu/1, lire_choix/0, traiter_choix/3, calculer_total/1]).

client(Dest, Commande) ->
    afficher_menu(Commande),
    Choice = lire_choix(),
    traiter_choix(Dest, Choice, Commande).

afficher_menu([]) ->
    io:format("~n====== FAST-FOOD MENU ======~n"),
    io:format("1 - Burger (3.50 EUR)~n"),
    io:format("2 - Frites (1.50 EUR)~n"),
    io:format("3 - Boisson (1.00 EUR)~n"),
    io:format("4 - Voir ma commande~n"),
    io:format("5 - Valider et quitter~n"),
    io:format("============================~n");
afficher_menu(_Commande) ->
    io:format("~n====== FAST-FOOD MENU ======~n"),
    io:format("1 - Burger (3.50 EUR)~n"),
    io:format("2 - Frites (1.50 EUR)~n"),
    io:format("3 - Boisson (1.00 EUR)~n"),
    io:format("4 - Voir ma commande~n"),
    io:format("5 - Valider et quitter~n"),
    io:format("6 - Supprimer un article~n"),
    io:format("============================~n").

lire_choix() ->
    case io:fread("Votre choix : ", "~d") of
        {ok, [Choix]} -> Choix;
        _ -> 0
    end.

traiter_choix(Dest, 1, Commande) ->
    io:format("CLIENT : Je commande un Burger.~n"),
    Dest ! {self(), burger},
    client(Dest, [burger | Commande]);
traiter_choix(Dest, 2, Commande) ->
    io:format("CLIENT : Je commande des Frites.~n"),
    Dest ! {self(), frites},
    client(Dest, [frites | Commande]);
traiter_choix(Dest, 3, Commande) ->
    io:format("CLIENT : Je commande une Boisson.~n"),
    Dest ! {self(), boisson},
    client(Dest, [boisson | Commande]);
traiter_choix(Dest, 4, Commande) ->
    io:format("CLIENT : Ma commande : ~p~n", [Commande]),
    Dest ! {self(), {recap, Commande}},
    client(Dest, Commande);
traiter_choix(Dest, 5, Commande) ->
    Total = calculer_total(Commande),
    io:format("CLIENT : Je valide ma commande d'un montant de ~.2f EUR.~n", [Total]),
    io:format("Détail : ~p~n", [Commande]),
    Dest ! {self(), fin};
traiter_choix(Dest, 6, Commande) ->
    io:format("Quel article supprimer ? (burger, frites, boisson) : "),
    case io:fread("", "~a") of
        {ok, [Article]} ->
            case lists:member(Article, Commande) of
                true ->
                    io:format("CLIENT : Je supprime ~p.~n", [Article]),
                    Dest ! {self(), {supprimer, Article}},
                    client(Dest, lists:delete(Article, Commande));
                false ->
                    io:format("CLIENT : Cet article n'est pas dans le panier.~n"),
                    client(Dest, Commande)
            end;
        _ ->
            io:format("Entrée invalide.~n"),
            client(Dest, Commande)
    end;
traiter_choix(Dest, _, Commande) ->
    io:format("Choix invalide.~n"),
    client(Dest, Commande).

calculer_total(Liste) ->
    Prices = [{burger, 3.50}, {frites, 1.50}, {boisson, 1.00}],
    lists:foldl(fun(Item, Acc) ->
        case lists:keyfind(Item, 1, Prices) of
            {_, Price} -> Acc + Price;
            false -> Acc
        end
    end, 0.0, Liste).
```

---

## 🚀 Guide d'utilisation en réseau

### 1. Sur l'ordinateur SERVEUR (IP: 192.168.1.XX)
Ouvrez un terminal et lancez Erlang avec un nom et un cookie :
```bash
werl -name cuisine@192.168.1.XX -setcookie miam
```
Dans le shell Erlang :
```erlang
c(ffserver).
c(ffclient).
ffserver:start_remote().
```

### 2. Sur l'ordinateur CLIENT
Ouvrez un terminal et lancez Erlang avec le **même cookie** :
```bash
werl -name client1@192.168.1.YY -setcookie miam
```
Dans le shell Erlang :
```erlang
c(ffclient).
% On passe commande à la cuisine distante
ffclient:client({la_cuisine, 'cuisine@192.168.1.XX'}, []).
```

---
*Note : Assurez-vous que les deux ordinateurs acceptent les connexions entrantes sur les ports utilisés par Erlang (généralement via le port 4369 pour EPMD et des ports dynamiques).*
