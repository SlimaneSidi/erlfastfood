-module(ffserver).
-export([start/0, loop_serveur/0]).

start() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte ! ===~n"),
    ServerPid = spawn(?MODULE, loop_serveur, []),
    ffclient:client(ServerPid, []).

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