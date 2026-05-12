# 🍔 Projet ErlFastFood - Version Distribuée

## 🚀 Guide d'utilisation en réseau

### 1. Sur l'ordinateur SERVEUR (IP: 192.168.1.XX)
Ouvrez un terminal et lancez Erlang avec un nom et un cookie :
```bash
werl -name cuisine@192.168.1.XX -setcookie miam
```
Dans le shell Erlang :
```erlang
c(ffserver).
c(ffclient).
ffserver:start_remote().
```

### 2. Sur l'ordinateur CLIENT
Ouvrez un terminal et lancez Erlang avec le **même cookie** :
```bash
werl -name client1@192.168.1.YY -setcookie miam
```
Dans le shell Erlang :
```erlang
c(ffclient).
% On passe commande à la cuisine distante
ffclient:client({la_cuisine, 'cuisine@192.168.1.XX'}, []).
```

---
*Note : Assurez-vous que les deux ordinateurs acceptent les connexions entrantes sur les ports utilisés par Erlang (généralement via le port 4369 pour EPMD et des ports dynamiques).*
