%% Interface graphique simple pour le client fast-food.
%% Utilise wx. Communique avec ffserver via le même protocole
%% que ffclient ({self(), burger|frites|boisson|{recap,L}|{supprimer,A}|fin}).
%%
%% Lancement :
%%   ffui:start().                            %% serveur local enregistré (erlfastfood)
%%   ffui:start(erlfastfood).                 %% nom local
%%   ffui:start({erlfastfood, 'serveur@hote'}).  %% distant

-module(ffui).
-include_lib("wx/include/wx.hrl").
-export([start/0, start/1]).

-define(PRIX_BURGER,  3.50).
-define(PRIX_FRITES,  1.50).
-define(PRIX_BOISSON, 1.00).

-define(ID_BURGER,   1001).
-define(ID_FRITES,   1002).
-define(ID_BOISSON,  1003).
-define(ID_SUPPR,    1004).
-define(ID_VALIDER,  1005).
-define(ID_RECAP,    1006).

start() ->
    start(erlfastfood).

start(Dest) ->
    case Dest of
        {_Name, Node} when Node =/= node() ->
            case net_adm:ping(Node) of
                pong ->
                    io:format("UI : connexion OK avec ~p~n", [Node]);
                pang ->
                    io:format("UI : ATTENTION, noeud ~p injoignable "
                              "(cookie ? nom ? firewall ?)~n", [Node])
            end;
        _ -> ok
    end,
    spawn(fun() -> init(Dest) end).

init(Dest) ->
    Wx = wx:new(),
    Frame = wxFrame:new(Wx, ?wxID_ANY, "Fast-Food", [{size, {520, 480}}]),

    Panel = wxPanel:new(Frame),
    Sizer = wxBoxSizer:new(?wxVERTICAL),

    Titre = wxStaticText:new(Panel, ?wxID_ANY, "Bienvenue ! Choisissez vos articles :"),
    Font  = wxFont:new(14, ?wxFONTFAMILY_DEFAULT, ?wxFONTSTYLE_NORMAL, ?wxFONTWEIGHT_BOLD),
    wxStaticText:setFont(Titre, Font),
    wxSizer:add(Sizer, Titre, [{flag, ?wxALL}, {border, 10}]),

    %% Boutons d'ajout
    BtnSizer = wxBoxSizer:new(?wxHORIZONTAL),
    BBurger  = wxButton:new(Panel, ?ID_BURGER,  [{label, "Burger\n3.50 EUR"}]),
    BFrites  = wxButton:new(Panel, ?ID_FRITES,  [{label, "Frites\n1.50 EUR"}]),
    BBoisson = wxButton:new(Panel, ?ID_BOISSON, [{label, "Boisson\n1.00 EUR"}]),
    wxSizer:add(BtnSizer, BBurger,  [{proportion, 1}, {flag, ?wxALL bor ?wxEXPAND}, {border, 5}]),
    wxSizer:add(BtnSizer, BFrites,  [{proportion, 1}, {flag, ?wxALL bor ?wxEXPAND}, {border, 5}]),
    wxSizer:add(BtnSizer, BBoisson, [{proportion, 1}, {flag, ?wxALL bor ?wxEXPAND}, {border, 5}]),
    wxSizer:add(Sizer, BtnSizer, [{flag, ?wxEXPAND bor ?wxLEFT bor ?wxRIGHT}, {border, 5}]),

    %% Liste de la commande
    LblCmd = wxStaticText:new(Panel, ?wxID_ANY, "Votre commande :"),
    wxSizer:add(Sizer, LblCmd, [{flag, ?wxLEFT bor ?wxTOP}, {border, 10}]),
    Liste = wxListBox:new(Panel, ?wxID_ANY, []),
    wxSizer:add(Sizer, Liste, [{proportion, 1}, {flag, ?wxALL bor ?wxEXPAND}, {border, 10}]),

    %% Total
    Total = wxStaticText:new(Panel, ?wxID_ANY, "Total : 0.00 EUR"),
    wxStaticText:setFont(Total, Font),
    wxSizer:add(Sizer, Total, [{flag, ?wxLEFT bor ?wxBOTTOM}, {border, 10}]),

    %% Actions
    ActSizer = wxBoxSizer:new(?wxHORIZONTAL),
    BSuppr   = wxButton:new(Panel, ?ID_SUPPR,   [{label, "Supprimer la sélection"}]),
    BRecap   = wxButton:new(Panel, ?ID_RECAP,   [{label, "Envoyer récap"}]),
    BValider = wxButton:new(Panel, ?ID_VALIDER, [{label, "Valider et quitter"}]),
    wxSizer:add(ActSizer, BSuppr,   [{proportion, 1}, {flag, ?wxALL bor ?wxEXPAND}, {border, 5}]),
    wxSizer:add(ActSizer, BRecap,   [{proportion, 1}, {flag, ?wxALL bor ?wxEXPAND}, {border, 5}]),
    wxSizer:add(ActSizer, BValider, [{proportion, 1}, {flag, ?wxALL bor ?wxEXPAND}, {border, 5}]),
    wxSizer:add(Sizer, ActSizer, [{flag, ?wxEXPAND bor ?wxALL}, {border, 5}]),

    wxPanel:setSizer(Panel, Sizer),

    %% Branche les events sur le process courant (la boucle ci-dessous)
    wxFrame:connect(Frame, close_window),
    wxFrame:connect(Frame, command_button_clicked),

    wxFrame:show(Frame),

    State = #{frame => Frame, liste => Liste, total => Total,
              dest  => Dest,  commande => []},
    loop(State).

loop(State) ->
    receive
        #wx{event = #wxClose{}} ->
            envoyer(State, fin),
            wxFrame:destroy(maps:get(frame, State)),
            wx:destroy(),
            ok;

        #wx{id = ?ID_BURGER,  event = #wxCommand{type = command_button_clicked}} ->
            loop(ajouter(burger,  State));
        #wx{id = ?ID_FRITES,  event = #wxCommand{type = command_button_clicked}} ->
            loop(ajouter(frites,  State));
        #wx{id = ?ID_BOISSON, event = #wxCommand{type = command_button_clicked}} ->
            loop(ajouter(boisson, State));

        #wx{id = ?ID_SUPPR, event = #wxCommand{type = command_button_clicked}} ->
            loop(supprimer_selection(State));

        #wx{id = ?ID_RECAP, event = #wxCommand{type = command_button_clicked}} ->
            envoyer(State, {recap, maps:get(commande, State)}),
            loop(State);

        #wx{id = ?ID_VALIDER, event = #wxCommand{type = command_button_clicked}} ->
            envoyer(State, fin),
            wxFrame:destroy(maps:get(frame, State)),
            wx:destroy(),
            ok;

        _Autre ->
            loop(State)
    end.

%% Systeme de commande

ajouter(Article, State = #{commande := Cmd}) ->
    envoyer(State, Article),
    NewState = State#{commande := Cmd ++ [Article]},
    rafraichir(NewState),
    NewState.

supprimer_selection(State = #{liste := Liste, commande := Cmd}) ->
    case wxListBox:getSelection(Liste) of
        -1 -> State;
        Idx ->
            Article = lists:nth(Idx + 1, Cmd),
            envoyer(State, {supprimer, Article}),
            NewCmd = supprimer_index(Idx + 1, Cmd),
            NewState = State#{commande := NewCmd},
            rafraichir(NewState),
            NewState
    end.

supprimer_index(N, L) ->
    {Avant, [_|Apres]} = lists:split(N - 1, L),
    Avant ++ Apres.

rafraichir(#{liste := Liste, total := Total, commande := Cmd}) ->
    wxListBox:clear(Liste),
    lists:foreach(fun(Art) ->
        wxListBox:append(Liste, libelle(Art))
    end, Cmd),
    Txt = io_lib:format("Total : ~.2f EUR", [calcul_total(Cmd)]),
    wxStaticText:setLabel(Total, lists:flatten(Txt)).

libelle(burger)  -> "Burger   3.50 EUR";
libelle(frites)  -> "Frites   1.50 EUR";
libelle(boisson) -> "Boisson  1.00 EUR".

prix(burger)  -> ?PRIX_BURGER;
prix(frites)  -> ?PRIX_FRITES;
prix(boisson) -> ?PRIX_BOISSON.

calcul_total(Cmd) ->
    lists:foldl(fun(A, Acc) -> Acc + prix(A) end, 0.0, Cmd).

%% Communication serveur

envoyer(#{dest := Dest}, Msg) ->
    try Dest ! {self(), Msg}
    catch Class:Reason ->
        io:format("UI : envoi vers ~p échoué (~p:~p)~n", [Dest, Class, Reason]),
        ok
    end.
