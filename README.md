# ErlFastFood

Projet fast-food en Erlang

#### Membres : Mathis MESSINGUIRAL, Ange Vanessa MANDJEU SAPPELLE, Roche Kevin EKO'O MEKULU, Robin NULLANS.

## Option 1 : Test local

    c(ffserver).
    c(ffclient).
    c(ffui).
    ffserver:start_local().

Pour utiliser l'interface graphique au lieu du client console, dans un **second** shell Erlang :

    c(ffui).
    ffui:start().

## Option 2 : Mode réseau

### Coté Serveur (IP ex : 192.168.1.10)

    erl -name serveur@192.168.1.10 -setcookie test

    c(ffserver).
    c(ffclient).
    ffserver:start_remote().

### Coté Client console (IP ex : 192.168.1.20)

    erl -name client1@192.168.1.20 -setcookie test

    c(ffclient).
    ffclient:client({erlfastfood, 'serveur@192.168.1.10'}, []).

### Coté Client UI (IP ex : 192.168.1.20)

    erl -name client1@192.168.1.20 -setcookie test

    c(ffui).
    ffui:start({erlfastfood, 'serveur@192.168.1.10'}).

## ATTENTION

- Les **cookies** doivent être identiques pour le serveur et tous les clients (ici `test`).
- En cas de problème, vérifier la connexion depuis le client avec `net_adm:ping('serveur@192.168.1.10').` qui doit retourner `pong`. Si `pang` → cookie, nom de nœud, ou firewall (EPMD port 4369).
