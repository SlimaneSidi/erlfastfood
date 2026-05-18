-module(ffserver).
-export([start_local/0, start_remote/0, loop_serveur/0]).

%% test sur la meme machine (local)
start_local() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte (Local) ===~n"),
    ServerPid = spawn(?MODULE, loop_serveur, []),
    register(erlfastfood, ServerPid),
    ffclient:client(erlfastfood, []).

%% Lance le serveur
start_remote() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte (Réseau) ===~n"),
    ServerPid = spawn(?MODULE, loop_serveur, []),
    register(erlfastfood, ServerPid),
    io:format("En attente de clients sur le noeud : ~p~n", [node()]).

loop_serveur() ->
    receive
        {_From, burger} ->
            io:format("CUISINE : Burger prêt.~n"),
            loop_serveur();
        {_From, frites} ->
            io:format("CUISINE : Frites prêtes.~n"),
            loop_serveur();
        {_From, boisson} ->
            io:format("CUISINE : Boisson prête.~n"),
            loop_serveur();
        {_From, {recap, Liste}} ->
            io:format("CUISINE : Récapitulatif : ~p~n", [Liste]),
            loop_serveur();
        {_From, {supprimer, Article}} ->
            io:format("CUISINE : Article ~p annulé.~n", [Article]),
            loop_serveur();
        {_From, fin} ->
            io:format("CUISINE : Commande terminée. A bientôt !~n")
    end.