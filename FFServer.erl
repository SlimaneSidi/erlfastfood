-module(ffserver).
-export([start_local/0, start/0, loop/0]).

%% test sur la meme machine (local)
start_local() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte ===~n"),
    ServerPid = spawn(ffserver, loop, []),
    register(erlfastfood, ServerPid),
    ffclient:client(erlfastfood, []).

%% Lance le serveur
start() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte ===~n"),
    ServerPid = spawn(ffserver, loop, []),
    register(erlfastfood, ServerPid),
    io:format("En attente de clients sur le noeud : ~p~n", [node()]).

loop() ->
    receive
        {_From, {burger, Ing}} ->
            io:format("CUISINE : Burger en préparation (ingrédients : ~s).~n",
                      [format_ingredients(Ing)]),
            loop();
        {_From, {frites, Taille}} ->
            io:format("CUISINE : Frites ~s prêtes.~n", [format_taille(Taille)]),
            loop();
        {_From, {boisson, Marque}} ->
            io:format("CUISINE : Boisson ~p servie.~n", [Marque]),
            loop();
        %% Compat avec l'ancien client texte (atomes simples)
        {_From, burger} ->
            io:format("CUISINE : Burger prêt.~n"),
            loop();
        {_From, frites} ->
            io:format("CUISINE : Frites prêtes.~n"),
            loop();
        {_From, boisson} ->
            io:format("CUISINE : Boisson prête.~n"),
            loop();
        {_From, {recap, Liste}} ->
            io:format("CUISINE : Récapitulatif : ~p~n", [Liste]),
            loop();
        {_From, {supprimer, Article}} ->
            io:format("CUISINE : Article ~p annulé.~n", [Article]),
            loop();
        {_From, fin} ->
            io:format("CUISINE : Commande terminée. A bientôt !~n")
    end.

format_ingredients([]) -> "nature";
format_ingredients(L)  ->
    string:join([atom_to_list(A) || A <- L], ", ").

format_taille(small)  -> "petites";
format_taille(medium) -> "moyennes";
format_taille(large)  -> "grandes";
format_taille(Other)  -> io_lib:format("~p", [Other]).
