-module('FFServer').
-export([start/0]).

start() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte ! ===~n"),
    Pid = spawn('FFClient', client, [self(), []]),
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