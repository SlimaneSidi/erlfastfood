%% Records partagés pour la BDD Mnesia du projet Erl-Fast-Food.

-record(commande, {id,
                   timestamp,
                   client,
                   items,
                   total}).

-record(menu_item, {id,
                    type,      %% burger_ingredient | boisson | frites
                    name,
                    price}).
