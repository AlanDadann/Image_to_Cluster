# 🚀 De Packer à K3d via Ansible

Ce projet automatise la création d'une image Docker personnalisée et son déploiement sur un cluster Kubernetes (K3d) en utilisant l'approche **Infrastructure as Code**.

**Architecture du pipeline :**
1. **Packer** : Construit une image Docker Nginx contenant une page HTML personnalisée.
2. **K3d** : Héberge le cluster Kubernetes local.
3. **Ansible** : Orchestre le déploiement (Namespace, Deployment, Service) sur K3d.

---

## ⚡ Méthode Automatique (Recommandée)

Un **Makefile** est inclus pour automatiser toutes les tâches.

### 1. Je suis un flemmard et je veux juste une commande à faire

Cette commande va construire l'image, l'importer dans le cluster et déployer l'application :

```bash
make

```

### Autres commandes utiles

* **Nettoyer le cluster** (supprime le namespace et les ressources) :
```bash
make clean

```


* **Vérifier les pods** :
```bash
make check

```



---

## 🛠️ Méthode Manuelle (Pas à pas)

Si vous souhaitez exécuter ou comprendre chaque étape individuellement, voici les commandes utilisées par le Makefile.

### Etape 0 : Préparation de l'environnement

1. Installation des outils (Packer, Ansible, K3d, lsof)

```bash
make install
```

2. Création du cluster K3d (nommé 'lab')
 
Cette commande expose le port 80 du cluster sur le port 8080 de votre machine

```bash
k3d cluster create lab --servers 1 --agents 2 --port 8080:80@loadbalancer
```

### Étape 1 : Construction de l'image (Packer)

Nous utilisons Packer pour créer une image Docker nommée `nginx-custom:latest` qui embarque le fichier `index.html`.

```bash
packer init build.pkr.hcl
packer build build.pkr.hcl

```

### Étape 2 : Import de l'image dans K3d

Le cluster K3d tourne dans des conteneurs isolés. Il faut importer l'image manuellement pour qu'elle soit visible par le cluster.

```bash
k3d image import nginx-custom:latest -c lab

```

### Étape 3 : Déploiement (Ansible)

Ansible communique avec l'API Kubernetes pour créer les ressources définies dans `deploy.yml`.
*Note : On force l'interpréteur Python pour s'assurer qu'Ansible trouve la librairie `kubernetes`.*

```bash
ansible-playbook deploy.yml -e "ansible_python_interpreter=$(which python3)"

```

---

## 🌐 Accéder à l'application

Une fois déployé, vous pouvez utiliser ces commandes :

1. **Vérifier que le pod tourne :**
```bash
kubectl get pods -n demo-ansible

```


2. **Accéder depuis le navigateur (Port-Forward) :**
Lancez cette commande pour lier le port 80 du service a un port disponible :
```bash
make forward

```




---

## 📂 Structure du projet

* `build.pkr.hcl` : Configuration Packer pour l'image Docker.
* `deploy.yml` : Playbook Ansible pour les objets Kubernetes.
* `index.html` : La page web personnalisée.
* `Makefile` : Script d'automatisation.

---
#Architecture du projet 👷🏾‍♂️

![Schéma représentatif de l'architecture du projet](Architecture_cible.png)

