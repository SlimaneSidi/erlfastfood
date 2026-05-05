-module('fast-food').
-export([start/0, client/2]).

start() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte ! ===~n"),
    Pid = spawn('fast-food', client, [self(), []]),
    loop_serveur(Pid).

loop_serveur(Pid) ->
    receive
        {Pid, burger} ->
            io:format("CUISINE : Burger en préparation... prêt !~n"),
            loop_serveur(Pid);
        {Pid, frites} ->
            io:format("CUISINE : Frites en préparation... prêtes !~n"),
            loop_serveur(Pid);
        {Pid, boisson} ->
            io:format("CUISINE : Boisson en préparation... prête !~n"),
            loop_serveur(Pid);
        {Pid, {recap, Liste}} ->
            io:format("CUISINE : Récapitulatif : ~p~n", [Liste]),
            loop_serveur(Pid);
        {Pid, fin} ->
            io:format("CUISINE : Commande terminée. Bonne dégustation !~n")
    end.

client(Pid, Commande) ->
    afficher_menu(),
    Choice = lire_choix(),
    traiter_choix(Pid, Choice, Commande).

afficher_menu() ->
    io:format("~n====== FAST-FOOD MENU ======~n"),
    io:format("1 - Burger (3.50 EUR)~n"),
    io:format("2 - Frites (1.50 EUR)~n"),
    io:format("3 - Boisson (1.00 EUR)~n"),
    io:format("4 - Voir ma commande~n"),
    io:format("5 - Valider et quitter~n"),
    io:format("============================~n").

lire_choix() ->
    case io:read("Votre choix : ") of
        {ok, Choix} -> Choix;
        _ -> 0
    end.

traiter_choix(Pid, 1, Commande) ->
    io:format("CLIENT : Je commande un Burger !~n"),
    Pid ! {self(), burger},
    client(Pid, [burger | Commande]);
traiter_choix(Pid, 2, Commande) ->
    io:format("CLIENT : Je commande des Frites !~n"),
    Pid ! {self(), frites},
    client(Pid, [frites | Commande]);
traiter_choix(Pid, 3, Commande) ->
    io:format("CLIENT : Je commande une Boisson !~n"),
    Pid ! {self(), boisson},
    client(Pid, [boisson | Commande]);
traiter_choix(Pid, 4, Commande) ->
    io:format("CLIENT : Ma commande : ~p~n", [Commande]),
    Pid ! {self(), {recap, Commande}},
    client(Pid, Commande);
traiter_choix(Pid, 5, Commande) ->
    io:format("CLIENT : Je valide : ~p~n", [Commande]),
    Pid ! {self(), fin};
traiter_choix(Pid, _, Commande) ->
    io:format("Choix invalide.~n"),
    client(Pid, Commande).