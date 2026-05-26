-module(ffserver).
-include("ffdb.hrl").
-export([start_local/0, start/0, loop/1,
         historique/0, afficher_historique/0]).

%% test sur la meme machine (local)
start_local() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte ===~n"),
    ok = init_db(),
    ServerPid = spawn(ffserver, loop, [#{}]),
    register(erlfastfood, ServerPid),
    ffclient:client(erlfastfood, []).

%% Lance le serveur
start() ->
    io:format("~n=== FAST-FOOD : La cuisine est ouverte ===~n"),
    ok = init_db(),
    ServerPid = spawn(ffserver, loop, [#{}]),
    register(erlfastfood, ServerPid),
    io:format("En attente de clients sur le noeud : ~p~n", [node()]).

%% Tente de démarrer Mnesia ; si les tables n'existent pas, lance l'install.
init_db() ->
    case ffdb:start() of
        ok -> ok;
        {error, {missing_tables, _}} ->
            io:format("CUISINE : initialisation de la BDD Mnesia...~n"),
            ffdb:install(),
            ffdb:start()
    end.

%% State = #{ClientPid => [Article, ...]} (commande en cours par client)
loop(State) ->
    receive
        {From, {burger, Ing}} ->
            io:format("CUISINE : Burger en préparation (ingrédients : ~s).~n",
                      [format_ingredients(Ing)]),
            loop(ajouter(From, {burger, Ing}, State));
        {From, {frites, Taille}} ->
            io:format("CUISINE : Frites ~s prêtes.~n", [format_taille(Taille)]),
            loop(ajouter(From, {frites, Taille}, State));
        {From, {boisson, Marque}} ->
            io:format("CUISINE : Boisson ~p servie.~n", [Marque]),
            loop(ajouter(From, {boisson, Marque}, State));

        %% Compat avec l'ancien client texte (atomes simples)
        {From, burger} ->
            io:format("CUISINE : Burger prêt.~n"),
            loop(ajouter(From, burger, State));
        {From, frites} ->
            io:format("CUISINE : Frites prêtes.~n"),
            loop(ajouter(From, frites, State));
        {From, boisson} ->
            io:format("CUISINE : Boisson prête.~n"),
            loop(ajouter(From, boisson, State));

        {From, {recap, Liste}} ->
            io:format("CUISINE : Récapitulatif pour ~p : ~p~n", [From, Liste]),
            loop(State);
        {From, {supprimer, Article}} ->
            io:format("CUISINE : Article ~p annulé pour ~p.~n", [Article, From]),
            loop(supprimer(From, Article, State));

        {From, fin} ->
            Items = maps:get(From, State, []),
            case Items of
                [] ->
                    io:format("CUISINE : ~p a quitté sans commander.~n", [From]);
                _ ->
                    {Id, Total} = ffdb:save_commande(From, Items),
                    io:format("CUISINE : Commande #~p sauvegardée (~p article(s), ~.2f EUR).~n",
                              [Id, length(Items), Total])
            end,
            loop(maps:remove(From, State));

        {From, historique} ->
            From ! {self(), {historique, ffdb:list_commandes()}},
            loop(State);

        Autre ->
            io:format("CUISINE : message inattendu ~p~n", [Autre]),
            loop(State)
    end.

ajouter(Client, Article, State) ->
    Cur = maps:get(Client, State, []),
    State#{Client => Cur ++ [Article]}.

supprimer(Client, Article, State) ->
    Cur = maps:get(Client, State, []),
    State#{Client => lists:delete(Article, Cur)}.

%% Accès direct à l'historique depuis le shell.
historique() ->
    ffdb:list_commandes().

afficher_historique() ->
    Commandes = ffdb:list_commandes(),
    io:format("~n=== Historique des commandes (~p) ===~n", [length(Commandes)]),
    lists:foreach(fun(#commande{id = Id, timestamp = Ts, client = C,
                                items = Items, total = Tot}) ->
        io:format("  #~p [~s] client=~p total=~.2f EUR~n     items=~p~n",
                  [Id, format_ts(Ts), C, Tot, Items])
    end, Commandes),
    io:format("=====================================~n").

format_ts({{Y,M,D},{H,Mi,S}}) ->
    io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w",
                  [Y,M,D,H,Mi,S]).

format_ingredients([]) -> "nature";
format_ingredients(L)  ->
    string:join([atom_to_list(A) || A <- L], ", ").

format_taille(small)  -> "petites";
format_taille(medium) -> "moyennes";
format_taille(large)  -> "grandes";
format_taille(Other)  -> io_lib:format("~p", [Other]).
