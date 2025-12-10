
# À propos des Gitlab Runners

## Utiliser l'image 'own-gitlab-runner' pour créer des runners automatiquement

### Description

Cette image permet de créer et d'enregister dynamiquement un ou plusieurs runners, avec des paramètres définis.
En lance le processus `gitlab-runner`, puis en parallèle gère l'enregistrement des nouveaux runners (après suppression des existants, si présents dans la config)

### Utilisation

En local, le plus simple est d'utiliser le fichier `docker-compose.yml` fourni.
Il est également possible d'utiliser `docker run` ou swarm au lieu de `docker-compose`.

Ne pas oublier de renseigner les paramètres requis (notamment le `REGISTRATION_TOKEN` et le `PROXY_URL` si besoin).

**Il est possible de modifier le fichier de base `config.toml` pour modifier les paramètres avancés s'appliquant à tous les runners.**

### Paramètres

| Nom                       | Description                                               | Valeur par défaut |
|---------------------------|-----------------------------------------------------------|-------------------|
| CI_SERVER_URL             | URL du serveur Gitlab                                     | `https://gitlab-forge.din.developpement-durable.gouv.fr/` |
| REGISTER_RUN_UNTAGGED     | Le runner doit-il exécuter des jobs sans tag ?            | `true` |
| RUNNER_TAG_LIST           | Liste des tags affectés à ce runner                       | `docker,generated` |
| RUNNER_EXECUTOR           | Type de runner                                            | `docker` |
| DOCKER_IMAGE              | Image de base utilisée par le runner                      | `ruby:2.6` |
| RUNNERS_COUNT             | Nombre de runners à créer                                 | 2 |
| RUNNER_NAME               | Nom d'affichage du runner                                 | `docker-generated-runner` |
| REGISTRATION_TOKEN_SECRET | Nom du secret contenant le jeton d'enregistrement         | `gitlab-runner-token-v1.0` |
| REGISTRATION_TOKEN        | Jeton d'enregistrement de Runner (à récupérer sur Gitlab) | Aucune |
| PROXY_URL                 | URL du proxy http(s), si nécessaire                       | Aucune |
| DEBUG                     | Activation du debug                                       | Aucune |

---

## Procédure manuelle (pas forcément à jour)

0. Récupérer et exécuter le script d'ajouter du dépôt Gitlab
```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash

# alternative
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" -o script.deb.sh
chmod +x script.deb.sh
sudo bash script.deb.sh

# en cas de problème à la fin du script, exécuter manuellement
curl 'https://packages.gitlab.com/install/repositories/runner/gitlab-runner/config_file.list?os=debian&dist=buster&source=script'
export gpg_key_url=https://packages.gitlab.com/runner/gitlab-runner/gpgkey
curl -L "${gpg_key_url}" 2> /dev/null | sudo apt-key add -
sudo apt-get update
```

0. Modifier les préférences APT ( https://docs.docker.com/engine/install/debian/ )
```bash
cat <<EOF | sudo tee /etc/apt/preferences.d/pin-gitlab-runner.pref
Explanation: Prefer GitLab provided packages over the Debian native ones
Package: gitlab-runner
Pin: origin packages.gitlab.com
Pin-Priority: 1001
EOF
```

0. Installer `gitlab-runner`
```bash
sudo apt-get update
sudo apt-get install gitlab-runner
```

0. Enregistrer le runner ( https://docs.gitlab.com/runner/register/index.html )
```bash
# Sur le Gitlab, aller dans le projet (ou groupe), dans Settings > CI/CD
#
# Dans "Set up a group runner manually", récupérer l'URL et le token
#
sudo gitlab-runner register
sudo -E gitlab-runner register # si derrière un proxy, après setup des variables
#
# Entrer les informations demandés : 
#   URL, token, nom de la machine, tags (docker, all)? executor (docker), image (alpine:latest)
```

0. Vérifier les logs du runner
```bash
journalctl -u gitlab-runner -f
```

0. Configurer le proxy pour le runner
```bash
sudo mkdir /etc/systemd/system/gitlab-runner.service.d
sudo nano /etc/systemd/system/gitlab-runner.service.d/http-proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart gitlab-runner
systemctl show --property=Environment gitlab-runner

[Service]
Environment="HTTP_PROXY=http://docker0_interface_ip:3128/"
Environment="HTTPS_PROXY=http://docker0_interface_ip:3128/"

[Service]
Environment="HTTP_PROXY=http://proxycs.csac.melanie2.i2:3128/"
Environment="HTTPS_PROXY=http://proxycs.csac.melanie2.i2:3128/"
```

0. Configurer le proxy pour Docker
```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo nano /etc/systemd/system/docker.service.d/http-proxy.conf

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show --property=Environment docker
```

https://docs.gitlab.com/ee/ci/docker/using_kaniko.html#building-an-image-with-kaniko-behind-a-proxy
```
environment = ["proxy_url=http://172.17.0.1:3128", "https_proxy=$proxy_url", "http_proxy=$proxy_url", "HTTPS_PROXY=$proxy_url", "HTTP_PROXY=$proxy_url"]
environment = ["proxy_url=http://proxycs.csac.melanie2.i2:3128/", "https_proxy=$proxy_url", "http_proxy=$proxy_url", "HTTPS_PROXY=$proxy_url", "HTTP_PROXY=$proxy_url"]
pre_clone_script = "git config --global http.proxy $HTTP_PROXY; git config --global https.proxy $HTTPS_PROXY"
```

0. Connexion au registry Gitlab

Un docker login peut être nécessaire, le runner stocke alors les identifiants dans `/root/.docker/config.json` et les réutilise si besoin
Cependant, cela peut entrer en conflit avec vos scripts de CI* ... Pensez dans ce cas à supprimer/renommer le fichier `/root/.docker/config.json`
```
docker login registry.gitlab-forge.din.developpement-durable.gouv.fr -u NOM_MACHINE -p PASSWORD_TOKEN
```

(* En effet, Gitlab peut utiliser les crédentials propre au job, Kaniko peut construite et utiliser `/kaniko/.docker/config.json`, etc)

---

## Liens utiles

- https://docs.gitlab.com/runner/configuration/proxy.html#adding-proxy-variables-to-the-gitlab-runner-configuration
- https://docs.gitlab.com/ee/ci/docker/using_kaniko.html#building-an-image-with-kaniko-behind-a-proxy
- https://docs.gitlab.com/runner/configuration/advanced-configuration.html