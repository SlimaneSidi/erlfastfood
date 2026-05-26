%% BDD Mnesia ErlFastFood

-record(commande, {id,
                   time,
                   client,
                   produits,
                   total}).

-record(menu_item, {id,
                    type,      %% burger_ingredient, boisson, frites
                    name,
                    price}).
