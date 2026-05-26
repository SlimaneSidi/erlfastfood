-module(ffdb).
-include("ffdb.hrl").

-export([install/0, install/1, start/0, stop/0,
         save_commande/2, list_commandes/0, get_commande/1, clear_commandes/0,
         seed_menu/0, list_menu/0, list_menu/1,
         prix_article/1, calcul_total/1,
         nom_ingredient/1, nom_boisson/1, nom_taille/1, libelle/1]).

%% Prix des bases (les suppléments / boissons sont dans la table menu_item)
-define(PRIX_BURGER,    3.50).
-define(PRIX_FRITES_S,  1.00).
-define(PRIX_FRITES_M,  1.50).
-define(PRIX_FRITES_L,  2.20).

%% ====================================================================
%% Installation / cycle de vie
%% ====================================================================

%% A appeler une seule fois pour créer le schéma sur disque.
install() ->
    install([node()]).

install(Nodes) ->
    case mnesia:create_schema(Nodes) of
        ok -> ok;
        {error, {_, {already_exists, _}}} -> ok;
        Other -> io:format("ffdb: create_schema -> ~p~n", [Other])
    end,
    application:start(mnesia),
    creer_table(commande,
                [{attributes, record_info(fields, commande)},
                 {disc_copies, Nodes},
                 {type, set}]),
    creer_table(menu_item,
                [{attributes, record_info(fields, menu_item)},
                 {disc_copies, Nodes},
                 {type, set}]),
    mnesia:wait_for_tables([commande, menu_item], 5000),
    seed_menu(),
    io:format("ffdb : installation Mnesia terminée sur ~p~n", [Nodes]),
    ok.

creer_table(Nom, Opts) ->
    case mnesia:create_table(Nom, Opts) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, Nom}} -> ok;
        Other -> io:format("ffdb: create_table ~p -> ~p~n", [Nom, Other])
    end.

%% Démarrage normal (à appeler par le serveur au boot).
start() ->
    application:start(mnesia),
    case mnesia:wait_for_tables([commande, menu_item], 5000) of
        ok ->
            io:format("ffdb : Mnesia prêt (~p commande(s) en BDD)~n",
                      [length(list_commandes())]),
            ok;
        {timeout, Manquantes} ->
            io:format("ffdb : tables manquantes ~p, lancez ffdb:install().~n",
                      [Manquantes]),
            {error, {missing_tables, Manquantes}}
    end.

stop() ->
    application:stop(mnesia).

%% ====================================================================
%% Commandes : persistance
%% ====================================================================

save_commande(Client, Items) ->
    Id = erlang:unique_integer([positive, monotonic]),
    Total = calcul_total(Items),
    Rec = #commande{id        = Id,
                    timestamp = calendar:local_time(),
                    client    = Client,
                    items     = Items,
                    total     = Total},
    F = fun() -> mnesia:write(Rec) end,
    {atomic, ok} = mnesia:transaction(F),
    {Id, Total}.

list_commandes() ->
    F = fun() ->
            mnesia:select(commande, [{'_', [], ['$_']}])
        end,
    {atomic, L} = mnesia:transaction(F),
    lists:sort(fun(#commande{id = A}, #commande{id = B}) -> A =< B end, L).

get_commande(Id) ->
    F = fun() -> mnesia:read({commande, Id}) end,
    case mnesia:transaction(F) of
        {atomic, [Rec]} -> {ok, Rec};
        {atomic, []}    -> not_found
    end.

clear_commandes() ->
    {atomic, ok} = mnesia:clear_table(commande),
    ok.

%% ====================================================================
%% Menu : catalogue persistant
%% ====================================================================

seed_menu() ->
    F = fun() ->
        Existant = mnesia:select(menu_item, [{'_', [], ['$_']}]),
        case Existant of
            [] ->
                [mnesia:write(I) || I <- menu_par_defaut()],
                {seeded, length(menu_par_defaut())};
            _ ->
                {kept, length(Existant)}
        end
    end,
    {atomic, Res} = mnesia:transaction(F),
    Res.

list_menu() ->
    F = fun() -> mnesia:select(menu_item, [{'_', [], ['$_']}]) end,
    {atomic, L} = mnesia:transaction(F),
    L.

list_menu(Type) ->
    [I || I = #menu_item{type = T} <- list_menu(), T =:= Type].

menu_par_defaut() ->
    Ingredients =
        [{cheese,           "Cheddar fondu",      0.50},
         {bacon,            "Bacon",              0.80},
         {salade,           "Salade fraîche",     0.20},
         {tomate,           "Tomate",             0.20},
         {oignons,          "Oignons rouges",     0.20},
         {pickles,          "Pickles",            0.20},
         {sauce_bbq,        "Sauce BBQ maison",   0.30},
         {sauce_algerienne, "Sauce algérienne",   0.30},
         {jalapenos,        "Jalapeños piquants", 0.40},
         {oeuf,             "Oeuf au plat",       0.60}],
    Boissons =
        [{coka_cola,  "Coké-Cola",          2.00},
         {coka_zero,  "Coka-Cola Zéro",     2.00},
         {pepsy_max,  "Pepsy Max",          1.90},
         {sprout,     "Sprout citronné",    1.80},
         {fantasia,   "Fantasia Orange",    1.80},
         {orangin,    "Orangin pulpé",      2.10},
         {seven_down, "7-Down",             1.70},
         {vittello,   "Eau plate Vittello", 1.00},
         {perriay,    "Perriay pétillante", 1.50},
         {redbool,    "Red Bool énergie",   2.80}],
    [#menu_item{id = Id, type = burger_ingredient, name = Nom, price = Px}
        || {Id, Nom, Px} <- Ingredients]
    ++
    [#menu_item{id = Id, type = boisson, name = Nom, price = Px}
        || {Id, Nom, Px} <- Boissons]
    ++
    [#menu_item{id = small,  type = frites, name = "Petite",  price = ?PRIX_FRITES_S},
     #menu_item{id = medium, type = frites, name = "Moyenne", price = ?PRIX_FRITES_M},
     #menu_item{id = large,  type = frites, name = "Grande",  price = ?PRIX_FRITES_L}].

%% ====================================================================
%% Helpers (lecture du catalogue + tarifs)
%% ====================================================================

lookup_price(Id) ->
    F = fun() -> mnesia:read({menu_item, Id}) end,
    case mnesia:transaction(F) of
        {atomic, [#menu_item{price = P}]} -> P;
        _ -> 0.0
    end.

lookup_name(Id) ->
    F = fun() -> mnesia:read({menu_item, Id}) end,
    case mnesia:transaction(F) of
        {atomic, [#menu_item{name = N}]} -> N;
        _ -> atom_to_list(Id)
    end.

prix_article({burger, Ing}) ->
    lists:foldl(fun(A, Acc) -> Acc + lookup_price(A) end, ?PRIX_BURGER, Ing);
prix_article({frites, Taille}) ->
    lookup_price(Taille);
prix_article({boisson, Marque}) ->
    lookup_price(Marque);
%% Compat avec l'ancien protocole texte (atomes nus).
prix_article(burger)  -> ?PRIX_BURGER;
prix_article(frites)  -> ?PRIX_FRITES_M;
prix_article(boisson) -> 1.00;
prix_article(_)       -> 0.0.

calcul_total(Items) ->
    lists:foldl(fun(A, Acc) -> Acc + prix_article(A) end, 0.0, Items).

nom_ingredient(A) -> lookup_name(A).
nom_boisson(A)    -> lookup_name(A).
nom_taille(small)  -> "petites";
nom_taille(medium) -> "moyennes";
nom_taille(large)  -> "grandes";
nom_taille(X)      -> io_lib:format("~p", [X]).

libelle({burger, []}) ->
    io_lib:format("Burger nature (~.2f EUR)", [?PRIX_BURGER]);
libelle({burger, Ing}) ->
    Noms = string:join([nom_ingredient(A) || A <- Ing], ", "),
    io_lib:format("Burger [~ts] (~.2f EUR)",
                  [Noms, prix_article({burger, Ing})]);
libelle({frites, Taille}) ->
    io_lib:format("Frites ~s (~.2f EUR)",
                  [nom_taille(Taille), prix_article({frites, Taille})]);
libelle({boisson, Marque}) ->
    io_lib:format("Boisson ~ts (~.2f EUR)",
                  [nom_boisson(Marque), prix_article({boisson, Marque})]);
libelle(Other) ->
    io_lib:format("~p", [Other]).
