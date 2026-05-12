-module(ffclient).
-export([client/2, afficher_menu/1, lire_choix/0, traiter_choix/3]).

client(Pid, Commande) ->
    afficher_menu(Commande),
    Choice = lire_choix(),
    traiter_choix(Pid, Choice, Commande).

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

traiter_choix(Pid, 1, Commande) ->
    io:format("CLIENT : Je commande un Burger.~n"),
    Pid ! {self(), burger},
    client(Pid, [burger | Commande]);
traiter_choix(Pid, 2, Commande) ->
    io:format("CLIENT : Je commande des Frites.~n"),
    Pid ! {self(), frites},
    client(Pid, [frites | Commande]);
traiter_choix(Pid, 3, Commande) ->
    io:format("CLIENT : Je commande une Boisson.~n"),
    Pid ! {self(), boisson},
    client(Pid, [boisson | Commande]);
traiter_choix(Pid, 4, Commande) ->
    io:format("CLIENT : Ma commande : ~p~n", [Commande]),
    Pid ! {self(), {recap, Commande}},
    client(Pid, Commande);
traiter_choix(Pid, 5, Commande) ->
    io:format("CLIENT : Je valide : ~p~n", [Commande]),
    Pid ! {self(), fin};
traiter_choix(Pid, 6, []) ->
    io:format("CLIENT : Le panier est vide, rien à supprimer.~n"),
    client(Pid, []);
traiter_choix(Pid, 6, Commande) ->
    io:format("Quel article supprimer ? (burger, frites, boisson) : "),
    case io:fread("", "~a") of
        {ok, [Article]} ->
            case lists:member(Article, Commande) of
                true ->
                    io:format("CLIENT : Je supprime ~p.~n", [Article]),
                    Pid ! {self(), {supprimer, Article}},
                    client(Pid, lists:delete(Article, Commande));
                false ->
                    io:format("CLIENT : Cet article n'est pas dans le panier.~n"),
                    client(Pid, Commande)
            end;
        _ ->
            io:format("Entrée invalide.~n"),
            client(Pid, Commande)
    end;
traiter_choix(Pid, _, Commande) ->
    io:format("Choix invalide.~n"),
    client(Pid, Commande).