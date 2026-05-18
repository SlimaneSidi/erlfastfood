# ErlFastFood

Projet fast-food en Erlang

#### Membres : Mathis MESSINGUIRAL, Ange Vanessa MANDJEU SAPPELLE, Roche Kevin EKO'O MEKULU, Robin NULLANS.

## Option 1 : Test local

c(ffserver).
c(ffclient).
ffserver:start().

## Option 2 : Mode réseau

### Coté Serveur (IP ex : 192.168.1.10)

erl -name nom_du_noeud@192.168.1.10 -setcookie nom_cookie

c(ffserver).
c(ffclient).
ffserver:start_remote().

### Coté Client (IP ex : 192.168.1.20)

erl -name client1@192.168.1.20 -setcookie miam

c(ffclient).
ffclient:client({erlfastfood, 'nom_du_noeud@192.168.1.10'}, []).


## ATTENTION : Les cookies doivent être les mêmes pour le serveur et les clients.