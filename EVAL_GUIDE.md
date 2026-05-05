# Inception — Guide de préparation à l'évaluation

---

## PARTIE 1 — Vérifications préliminaires

### Le projet tourne sur une VM ?
Le sujet l'impose. L'évaluateur vérifiera que tu lances tout depuis une VM, pas depuis ta machine hôte.

### Structure des fichiers
L'évaluateur va faire `ls -alR` et vérifier :
```
inception/
├── Makefile
├── secrets/          ← fichiers de mots de passe (hors git)
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── conf/init.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   └── conf/init.sh
        └── nginx/
            ├── Dockerfile
            └── conf/
                ├── nginx.conf
                └── init.sh
```

### Le Makefile fonctionne ?
```bash
make        # doit tout builder et démarrer
make down   # doit tout arrêter
make re     # doit tout reconstruire proprement
```

---

## PARTIE 2 — Questions théoriques (tu DOIS savoir répondre)

### Docker vs Machine Virtuelle — quelle différence ?

**Machine Virtuelle** :
- Émule un ordinateur complet avec son propre OS (kernel inclus)
- Lourde, lente à démarrer (minutes), consomme beaucoup de RAM/CPU
- Isolation totale : chaque VM a son propre kernel

**Docker (conteneur)** :
- Partage le kernel de la machine hôte
- Léger, démarre en millisecondes
- Isolation des processus via `namespaces` Linux et `cgroups`
- Pas de kernel séparé → moins isolé qu'une VM, mais bien plus rapide

> Analogie : la VM c'est un appartement avec ses propres murs porteurs. Le conteneur c'est une pièce dans un appartement partagé — murs séparés mais même structure.

---

### C'est quoi un Dockerfile ?

Un fichier texte qui décrit comment construire une image Docker. Chaque ligne est une instruction :
- `FROM` — image de base (ici toujours `debian:bullseye`)
- `RUN` — exécute une commande pendant le build
- `COPY` — copie des fichiers dans l'image
- `EXPOSE` — documente le port utilisé (informatif, ne l'ouvre pas vraiment)
- `ENTRYPOINT` — commande lancée au démarrage du conteneur

```dockerfile
FROM debian:bullseye
RUN apt-get update && apt-get install -y nginx
COPY conf/init.sh /init.sh
ENTRYPOINT ["/init.sh"]
```

---

### C'est quoi une image Docker ?

Un snapshot en lecture seule de ton système de fichiers + métadonnées. Construite depuis un Dockerfile. Elle ne s'exécute pas — elle sert de modèle pour créer des conteneurs.

```
Dockerfile --build--> Image --run--> Conteneur (instance vivante)
```

---

### C'est quoi PID 1 et pourquoi c'est important ?

Dans Linux, le processus PID 1 est le père de tous les processus. Dans un conteneur Docker, le PID 1 est la commande lancée par l'`ENTRYPOINT`.

**Pourquoi c'est important** :
- Si PID 1 se termine → le conteneur s'arrête
- PID 1 reçoit les signaux système (SIGTERM, SIGINT) pour arrêter proprement le conteneur
- C'est pourquoi on utilise `exec` dans les scripts d'init : `exec nginx -g "daemon off;"` — `exec` **remplace** le shell par nginx, qui devient PID 1

**Ce qu'il ne faut PAS faire** :
```bash
nginx -g "daemon off;"   # nginx est PID 2, le shell est PID 1 → mauvais
exec nginx -g "daemon off;"  # nginx est PID 1 → correct
```

---

### Pourquoi `daemon off` pour NGINX ?

Par défaut, NGINX se lance en arrière-plan (daemon). Si on le laisse faire ça dans un conteneur, le script d'init se termine → PID 1 mort → conteneur stoppé immédiatement. `daemon off` force NGINX à rester au premier plan.

---

### Réseau Docker vs réseau Host

**Docker network (bridge)** — ce qu'on utilise :
- Crée un réseau virtuel privé entre les conteneurs
- Les conteneurs se parlent par leur nom (`mariadb`, `wordpress`, `nginx`)
- Isolation de l'extérieur : MariaDB n'est pas accessible depuis internet
- Le seul port exposé au monde est le 443 de NGINX

**Host network** — interdit par le sujet :
- Le conteneur partage directement le réseau de la machine hôte
- Pas d'isolation réseau
- Interdit : `network: host` et `--link` et `links:`

---

### Volumes nommés vs Bind Mounts

**Bind Mount** — interdit pour les données persistantes :
```yaml
volumes:
  - /home/stdevis/data/db:/var/lib/mysql  # bind mount direct
```
Lie directement un dossier de la machine hôte. Problème : dépendant du chemin exact de la machine.

**Volume nommé** — obligatoire par le sujet :
```yaml
volumes:
  db:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/stdevis/data/db
```
Docker gère le volume. Plus portable, Docker peut faire des backups, snapshots, etc.

> Les deux volumes doivent stocker leurs données dans `/home/stdevis/data/` sur la machine hôte.

---

### Secrets Docker vs Variables d'environnement

**Variables d'environnement (.env)** :
- Passées au conteneur via `env_file` ou `environment`
- Visibles dans `docker inspect`, dans `/proc/<pid>/environ`
- Moins sécurisées

**Docker Secrets** :
- Montées comme fichier dans `/run/secrets/` dans le conteneur
- Jamais dans les variables d'environnement
- Chiffrées au repos (en mode Swarm)
- Recommandées par le sujet pour les mots de passe

Pour ce projet : le `.env` est acceptable, mais il doit être dans `.gitignore` et **jamais commité**.

---

### Pourquoi pas `latest` comme tag ?

`latest` est un tag qui change à chaque nouvelle version. Si tu construis ton image aujourd'hui avec `debian:latest` et que demain Debian sort une nouvelle version, ton build change de comportement. En utilisant `debian:bullseye`, tu garantis la reproductibilité.

---

## PARTIE 3 — Vérifications techniques (ce que l'évaluateur teste)

### NGINX

**L'évaluateur vérifiera :**

```bash
# Seul port exposé = 443
docker ps  # nginx doit avoir 0.0.0.0:443->443/tcp

# TLS 1.2 ou 1.3 uniquement
openssl s_client -connect stdevis.42.fr:443 -tls1_2  # doit fonctionner
openssl s_client -connect stdevis.42.fr:443 -tls1     # doit ÉCHOUER

# Le site charge
curl -k https://stdevis.42.fr
```

**Ta config nginx.conf doit avoir :**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
listen 443 ssl;
# PAS de listen 80 (HTTP non chiffré interdit)
```

---

### MariaDB

**L'évaluateur vérifiera :**

```bash
# Se connecter à la DB
docker exec -it mariadb mysql -u root -prootpassword

# Vérifier la base wordpress existe
SHOW DATABASES;

# Vérifier les utilisateurs
SELECT User, Host FROM mysql.user;
# Doit montrer : root, wpuser

# Vérifier les droits de wpuser
SHOW GRANTS FOR 'wpuser'@'%';
```

**Points importants :**
- Pas de mot de passe en dur dans le Dockerfile
- Root a un mot de passe (sécurité)
- L'utilisateur WordPress (`wpuser`) n'a accès qu'à la DB `wordpress`

---

### WordPress

**L'évaluateur vérifiera :**

```bash
# WordPress tourne avec PHP-FPM sur le port 9000
docker exec wordpress ps aux  # doit montrer php-fpm

# Deux utilisateurs existent
# Aller sur https://stdevis.42.fr/wp-admin → Users
# Doit y avoir : master (admin) et user (author)
```

**Important :**
- L'admin ne doit pas s'appeler `admin`, `administrator`, `Admin`, etc.
- Le deuxième utilisateur est un simple auteur/éditeur

---

### Volumes

```bash
# Vérifier que les volumes existent
docker volume ls
# Doit montrer : inception_db et inception_wp

# Vérifier où les données sont stockées
ls /home/stdevis/data/db   # fichiers MariaDB
ls /home/stdevis/data/wp   # fichiers WordPress
```

**Test de persistance :**
```bash
make down
make
# WordPress doit charger immédiatement (pas de réinstallation)
# Les articles/settings doivent être préservés
```

---

### Sécurité

```bash
# Aucun mot de passe dans les Dockerfiles
grep -r "password" srcs/requirements/*/Dockerfile  # doit rien trouver

# Le .env ne doit PAS être dans git
git log --all -- srcs/.env  # ne doit rien montrer

# Les conteneurs redémarrent en cas de crash
docker kill wordpress
docker ps  # wordpress doit réapparaître automatiquement
```

---

### Réseau

```bash
# Un seul réseau Docker existe
docker network ls  # doit montrer "inception_inception" (bridge)

# Les conteneurs sont dans ce réseau
docker network inspect inception_inception

# Pas de network: host
grep "host" srcs/docker-compose.yml  # ne doit rien trouver
```

---

## PARTIE 4 — Questions pièges fréquentes

### "Montre-moi ton Dockerfile pour wordpress, explique chaque ligne"

Sois capable d'expliquer :
- Pourquoi `debian:bullseye` (pas `latest`, pas `wordpress` officiel)
- Pourquoi tu installes `php7.4-fpm` et pas juste `php`
- Pourquoi tu installes `wp-cli` (pour automatiser l'install WordPress en ligne de commande)
- Pourquoi l'ENTRYPOINT est un script et pas directement `php-fpm7.4 -F`

---

### "Pourquoi tu utilises `exec` à la fin de tes scripts ?"

Sans `exec` : le shell reste PID 1, le daemon est PID 2. Les signaux Docker (SIGTERM pour `docker stop`) ne sont pas transmis au daemon → arrêt brutal.

Avec `exec` : le daemon **remplace** le shell et devient PID 1. Il reçoit directement les signaux → arrêt propre.

---

### "Pourquoi MariaDB démarre en deux temps dans ton init.sh ?"

1. Premier démarrage avec `--skip-networking` : MariaDB tourne mais n'accepte pas de connexions réseau → on peut configurer en sécurité (créer DB, users, set root password)
2. On arrête cette instance temporaire
3. On lance le vrai `mysqld_safe` sans restriction → MariaDB écoute sur le port 3306 et est prête pour WordPress

---

### "Que se passe-t-il si le conteneur wordpress crashe ?"

`restart: unless-stopped` dans docker-compose → Docker redémarre automatiquement le conteneur. WordPress re-vérifie si `wp-login.php` existe (oui, car dans le volume) → pas de réinstallation → reprend normalement.

---

### "Comment nginx communique avec wordpress ?"

Via le protocole **FastCGI** sur le port **9000**. NGINX ne comprend pas PHP, il délègue l'exécution des `.php` à PHP-FPM via FastCGI. La directive dans nginx.conf :
```nginx
fastcgi_pass wordpress:9000;
```
`wordpress` est résolu par le DNS interne Docker → IP du conteneur wordpress.

---

### "Pourquoi le certificat TLS est auto-signé ?"

Pour un vrai site, on utiliserait Let's Encrypt (certificat signé par une autorité de certification reconnue). Ici on n'a pas de vrai domaine public, donc on génère nous-mêmes le certificat avec `openssl`. Le navigateur le refuse par défaut (avertissement) mais la connexion est quand même chiffrée.

---

## PARTIE 5 — Checklist finale avant évaluation

- [ ] `make` fonctionne et lance les 3 conteneurs
- [ ] `make down` stoppe tout proprement
- [ ] `https://stdevis.42.fr` charge WordPress dans le navigateur
- [ ] `https://stdevis.42.fr/wp-admin` accessible avec `master` / ton mot de passe
- [ ] Deux users WordPress : `master` (admin) et `user` (author)
- [ ] Le nom de l'admin ne contient pas "admin"
- [ ] MariaDB a `wpuser` avec accès à la DB `wordpress`
- [ ] Les données survivent à un `make down && make`
- [ ] Aucun mot de passe dans les Dockerfiles
- [ ] Le `.env` est dans `.gitignore` et absent du repo git
- [ ] Seul le port 443 est exposé à l'extérieur
- [ ] TLSv1.2 ou TLSv1.3 uniquement
- [ ] `restart: unless-stopped` sur tous les services
- [ ] Pas de `tail -f`, `sleep infinity`, `while true`, `bash` comme entrypoint
- [ ] Chaque service dans son propre conteneur
- [ ] Un seul réseau Docker de type bridge
- [ ] Volumes nommés (pas de bind mounts directs)
- [ ] Données dans `/home/stdevis/data/` sur la machine hôte
- [ ] README.md présent avec toutes les sections requises
- [ ] USER_DOC.md présent
- [ ] DEV_DOC.md présent

---

## PARTIE 6 — Bonus (évalué seulement si le mandatory est parfait)

| Bonus | Ce que ça fait |
|---|---|
| **Redis** | Cache pour WordPress — réduit les requêtes SQL |
| **FTP** | Accès aux fichiers WordPress via protocole FTP |
| **Site statique** | Un site HTML/CSS/JS (pas PHP) dans son propre conteneur |
| **Adminer** | Interface web pour gérer MariaDB (alternative phpMyAdmin) |
| **Service custom** | N'importe quel service utile — tu dois pouvoir le justifier |
