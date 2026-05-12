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