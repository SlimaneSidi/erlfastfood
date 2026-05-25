-module(ffui).
-include_lib("wx/include/wx.hrl").
-export([start/0, start/1]).

-define(PRIX_BURGER,  3.50).
-define(PRIX_FRITES_S, 1.00).
-define(PRIX_FRITES_M, 1.50).
-define(PRIX_FRITES_L, 2.20).

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
                    io:format("UI : ATTENTION, noeud ~p injoignable ", [Node])
            end;
        _ -> ok
    end,
    spawn(fun() -> init(Dest) end).

init(Dest) ->
    Wx = wx:new(),
    Frame = wxFrame:new(Wx, ?wxID_ANY, "Erl-Fast-Food", [{size, {560, 520}}]),

    Panel = wxPanel:new(Frame),

    %% Image de fond : chargée une fois, rescalée à chaque repaint.
    ImgPath = filename:join(["img", "RedBackground.png"]),
    Image = wxImage:new(ImgPath),
    case wxImage:isOk(Image) of
        true  ->
            attenuer_vers_blanc(Image, 0.35),
            io:format("UI : image de fond chargée (~ts)~n", [ImgPath]);
        false ->
            io:format("UI : ATTENTION, image de fond introuvable (~ts)~n",
                      [ImgPath])
    end,
    wxPanel:setBackgroundStyle(Panel, ?wxBG_STYLE_PAINT),

    Sizer = wxBoxSizer:new(?wxVERTICAL),

    Titre = wxStaticText:new(Panel, ?wxID_ANY, "Bienvenue ! Choisissez vos articles :"),
    Font  = wxFont:new(14, ?wxFONTFAMILY_DEFAULT, ?wxFONTSTYLE_NORMAL, ?wxFONTWEIGHT_BOLD),
    wxStaticText:setFont(Titre, Font),
    wxSizer:add(Sizer, Titre, [{flag, ?wxALL}, {border, 10}]),

    %% Boutons d'ajout
    BtnSizer = wxBoxSizer:new(?wxHORIZONTAL),
    BBurger  = wxButton:new(Panel, ?ID_BURGER,  [{label, "Burger\n(personnalisable)"}]),
    BFrites  = wxButton:new(Panel, ?ID_FRITES,  [{label, "Frites\n(S / M / L)"}]),
    BBoisson = wxButton:new(Panel, ?ID_BOISSON, [{label, "Boisson\n(au choix)"}]),
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

    wxFrame:connect(Frame, close_window),
    wxFrame:connect(Frame, command_button_clicked),

    %% Repaint / resize du fond.
    %% Paint en mode callback : wxPaintDC doit être créé dans le contexte
    %% du handler natif, sinon rien ne s'affiche.
    %% Size avec skip=true pour que le sizer continue à positionner les enfants.
    PaintCb = fun(_Ev, _) -> peindre_fond(Panel, Image) end,
    wxPanel:connect(Panel, paint, [{callback, PaintCb}]),
    wxPanel:connect(Panel, size, [{skip, true}]),

    wxFrame:show(Frame),

    State = #{frame => Frame, panel => Panel, image => Image,
              liste => Liste, total => Total,
              dest  => Dest,  commande => []},
    loop(State).

loop(State = #{frame := Frame, panel := Panel}) ->
    receive
        #wx{event = #wxClose{}} ->
            envoyer(State, fin),
            wxFrame:destroy(Frame),
            wx:destroy(),
            ok;

        #wx{event = #wxSize{}} ->
            wxPanel:refresh(Panel),
            loop(State);

        #wx{id = ?ID_BURGER,  event = #wxCommand{type = command_button_clicked}} ->
            loop(commander_burger(State));
        #wx{id = ?ID_FRITES,  event = #wxCommand{type = command_button_clicked}} ->
            loop(commander_frites(State));
        #wx{id = ?ID_BOISSON, event = #wxCommand{type = command_button_clicked}} ->
            loop(commander_boisson(State));

        #wx{id = ?ID_SUPPR, event = #wxCommand{type = command_button_clicked}} ->
            loop(supprimer_selection(State));

        #wx{id = ?ID_RECAP, event = #wxCommand{type = command_button_clicked}} ->
            envoyer(State, {recap, maps:get(commande, State)}),
            loop(State);

        #wx{id = ?ID_VALIDER, event = #wxCommand{type = command_button_clicked}} ->
            envoyer(State, fin),
            wxFrame:destroy(Frame),
            wx:destroy(),
            ok;

        _Autre ->
            loop(State)
    end.

%% Atténue l'image vers le blanc (effet "opacité réduite").
%% Force ∈ [0.0, 1.0] : 1.0 = image intacte, 0.0 = blanc total.
attenuer_vers_blanc(Image, Force) when Force >= 0.0, Force =< 1.0 ->
    Data = wxImage:getData(Image),
    A = round(Force * 255),
    Inv = 255 - A,
    Blended = << <<((P * A + 255 * Inv) div 255)>> || <<P>> <= Data >>,
    wxImage:setData(Image, Blended).

%% Peinture du fond (image rescalée à la taille courante du panel)

peindre_fond(Panel, Image) ->
    DC = wxPaintDC:new(Panel),
    {W, H} = wxPanel:getClientSize(Panel),
    case wxImage:isOk(Image) andalso W > 0 andalso H > 0 of
        true ->
            Scaled = wxImage:scale(Image, W, H,
                                   [{quality, ?wxIMAGE_QUALITY_HIGH}]),
            Bmp = wxBitmap:new(Scaled),
            wxDC:drawBitmap(DC, Bmp, {0, 0}),
            wxBitmap:destroy(Bmp),
            wxImage:destroy(Scaled);
        false ->
            %% Fallback rouge bien visible si l'image n'est pas exploitable.
            wxDC:setBackground(DC, wxBrush:new({255, 0, 0})),
            wxDC:clear(DC)
    end,
    wxPaintDC:destroy(DC).

%% Sous-sélections via dialogues

commander_burger(State = #{frame := Frame}) ->
    Ingredients = ingredients_burger(),
    Labels = [lists:flatten(io_lib:format("~ts (+~.2f EUR)", [Nom, Px]))
              || {_Atom, Nom, Px} <- Ingredients],
    Dlg = wxMultiChoiceDialog:new(Frame,
            "Composez votre burger (steak + pain inclus)",
            "Personnalisation du burger",
            Labels),
    case wxDialog:showModal(Dlg) of
        ?wxID_OK ->
            Idxs = wxMultiChoiceDialog:getSelections(Dlg),
            wxDialog:destroy(Dlg),
            Choisis = [lists:nth(I + 1, Ingredients) || I <- Idxs],
            Atoms = [A || {A, _, _} <- Choisis],
            ajouter({burger, Atoms}, State);
        _ ->
            wxDialog:destroy(Dlg),
            State
    end.

commander_frites(State = #{frame := Frame}) ->
    Tailles = [{small,  "Petite (1.00 EUR)"},
               {medium, "Moyenne (1.50 EUR)"},
               {large,  "Grande (2.20 EUR)"}],
    selection_simple(State, Frame, "Choisissez la taille des frites",
                     "Frites", Tailles,
                     fun(Atom) -> {frites, Atom} end).

commander_boisson(State = #{frame := Frame}) ->
    Boissons = boissons_dispo(),
    Options = [{Atom, lists:flatten(io_lib:format("~ts (~.2f EUR)", [Nom, Px]))}
               || {Atom, Nom, Px} <- Boissons],
    selection_simple(State, Frame, "Choisissez votre boisson",
                     "Boissons", Options,
                     fun(Atom) -> {boisson, Atom} end).

selection_simple(State, Frame, Message, Titre, Options, MakeArticle) ->
    Labels = [L || {_A, L} <- Options],
    Dlg = wxSingleChoiceDialog:new(Frame, Message, Titre, Labels),
    case wxDialog:showModal(Dlg) of
        ?wxID_OK ->
            Idx = wxSingleChoiceDialog:getSelection(Dlg),
            wxDialog:destroy(Dlg),
            {Atom, _} = lists:nth(Idx + 1, Options),
            ajouter(MakeArticle(Atom), State);
        _ ->
            wxDialog:destroy(Dlg),
            State
    end.

%% Catalogues

ingredients_burger() ->
    %% {atome, libellé affiché, supplément en EUR}
    [{cheese,  "Cheddar fondu", 0.50},
     {bacon,   "Bacon", 0.80},
     {salade,  "Salade fraîche", 0.20},
     {tomate,  "Tomate", 0.20},
     {oignons, "Oignons rouges", 0.20},
     {pickles, "Pickles", 0.20},
     {sauce_bbq,    "Sauce BBQ maison", 0.30},
     {sauce_algerienne, "Sauce algérienne", 0.30},
     {jalapenos, "Jalapeños piquants", 0.40},
     {oeuf,    "Oeuf au plat", 0.60}].

boissons_dispo() ->
    %% Marques inventées clin d'œil
    [{coka_cola,    "Coké-Cola",          2.00},
     {coka_zero,    "Coka-Cola Zéro",     2.00},
     {pepsy_max,    "Pepsy Max",          1.90},
     {sprout,       "Sprout citronné",    1.80},
     {fantasia,     "Fantasia Orange",    1.80},
     {orangin,      "Orangin pulpé",      2.10},
     {seven_down,   "7-Down",             1.70},
     {vittello,     "Eau plate Vittello", 1.00},
     {perriay,      "Perriay pétillante", 1.50},
     {redbool,      "Red Bool énergie",   2.80}].

prix_ingredient(Atom) ->
    case lists:keyfind(Atom, 1, ingredients_burger()) of
        {_, _, Px} -> Px;
        false -> 0.0
    end.

prix_boisson(Atom) ->
    case lists:keyfind(Atom, 1, boissons_dispo()) of
        {_, _, Px} -> Px;
        false -> 0.0
    end.

nom_ingredient(Atom) ->
    case lists:keyfind(Atom, 1, ingredients_burger()) of
        {_, Nom, _} -> Nom;
        false -> atom_to_list(Atom)
    end.

nom_boisson(Atom) ->
    case lists:keyfind(Atom, 1, boissons_dispo()) of
        {_, Nom, _} -> Nom;
        false -> atom_to_list(Atom)
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

%% Libellés affichés dans la liste

libelle({burger, []}) ->
    lists:flatten(io_lib:format("Burger nature   ~.2f EUR", [?PRIX_BURGER]));
libelle({burger, Ing}) ->
    Px = prix_article({burger, Ing}),
    NomsIng = string:join([nom_ingredient(A) || A <- Ing], ", "),
    lists:flatten(io_lib:format("Burger [~ts]   ~.2f EUR", [NomsIng, Px]));
libelle({frites, Taille}) ->
    Px = prix_article({frites, Taille}),
    Nom = case Taille of
              small -> "petites";
              medium -> "moyennes";
              large -> "grandes"
          end,
    lists:flatten(io_lib:format("Frites ~s   ~.2f EUR", [Nom, Px]));
libelle({boisson, Marque}) ->
    Px = prix_boisson(Marque),
    lists:flatten(io_lib:format("Boisson ~ts   ~.2f EUR",
                                [nom_boisson(Marque), Px])).

%% Tarification

prix_article({burger, Ing}) ->
    lists:foldl(fun(A, Acc) -> Acc + prix_ingredient(A) end,
                ?PRIX_BURGER, Ing);
prix_article({frites, small})  -> ?PRIX_FRITES_S;
prix_article({frites, medium}) -> ?PRIX_FRITES_M;
prix_article({frites, large})  -> ?PRIX_FRITES_L;
prix_article({boisson, Marque}) -> prix_boisson(Marque).

calcul_total(Cmd) ->
    lists:foldl(fun(A, Acc) -> Acc + prix_article(A) end, 0.0, Cmd).

%% Communication serveur

envoyer(#{dest := Dest}, Msg) ->
    try Dest ! {self(), Msg}
    catch Class:Reason ->
        io:format("UI : envoi vers ~p échoué (~p:~p)~n", [Dest, Class, Reason]),
        ok
    end.
