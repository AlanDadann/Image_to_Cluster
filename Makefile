# Variables
CLUSTER_NAME=lab
IMAGE_NAME=nginx-custom:latest
PYTHON_PATH=$(shell which python3)

# Liste des commandes
.PHONY: all install start-cluster build import deploy clean check forward

# --- ORDRE D'EXÉCUTION (Le Pipeline Complet) ---
all: install start-cluster build import deploy check forward 

# --- 1. INSTALLATION DES OUTILS (Y compris K3d) ---
install:
	@echo "🔧 1. Préparation de l'environnement..."
	# Correction du bug Yarn de Codespaces
	-sudo rm -f /etc/apt/sources.list.d/yarn.list
	
	# Installation des dépendances Linux
	sudo apt-get update || true
	sudo apt-get install -y curl wget software-properties-common
	# Installation des dépendances Linux (Ajout de lsof pour la gestion des ports)
	sudo apt-get update || true
	sudo apt-get install -y curl wget software-properties-common lsof
# ... suite du script

	# Installation de Packer (Repo HashiCorp)
	@if ! command -v packer >/dev/null; then \
		echo "📦 Installation de Packer..."; \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -; \
		sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" -y; \
		sudo apt-get update && sudo apt-get install -y packer; \
	else \
		echo "✅ Packer est déjà installé."; \
	fi

	# Installation d'Ansible
	sudo apt-get install -y ansible

	# Installation de K3d (Le Cluster)
	@if ! command -v k3d >/dev/null; then \
		echo "📦 Installation de K3d..."; \
		curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; \
	else \
		echo "✅ K3d est déjà installé."; \
	fi

	# Librairies Python pour Ansible
	$(PYTHON_PATH) -m pip install kubernetes
	ansible-galaxy collection install kubernetes.core --force

# --- 2. DÉMARRAGE DU CLUSTER ---
start-cluster:
	@echo "🔌 2. Vérification du cluster K3d..."
	@k3d cluster get $(CLUSTER_NAME) >/dev/null 2>&1 || \
		(echo "✨ Création du cluster '$(CLUSTER_NAME)'..." && \
		k3d cluster create $(CLUSTER_NAME) --servers 1 --agents 2 --port 8080:80@loadbalancer && \
		echo "💤 Pause technique (15s) pour la stabilisation des volumes..." && \
		sleep 15 && \
		echo "⏳ Attente que le nœud Master soit prêt..." && \
		kubectl wait --for=condition=Ready node --all --timeout=60s)
	@echo "✅ Cluster actif et chaud !"

# --- 3. BUILD PACKER ---
build:
	@echo "🏗️ 3. Construction de l'image Docker..."
	packer init build.pkr.hcl
	packer build build.pkr.hcl

# --- 4. IMPORT DANS K3D ---
import:
	@echo "📦 4. Import de l'image dans K3d..."
	k3d image import $(IMAGE_NAME) -c $(CLUSTER_NAME)

# --- 5. DÉPLOIEMENT ANSIBLE ---
deploy:
	@echo "🚀 5. Déploiement Ansible..."
	ansible-playbook deploy.yml -e "ansible_python_interpreter=$(PYTHON_PATH)"
	sleep 15

# --- NETTOYAGE ---
clean:
	@echo "🧹 Nettoyage..."
	-kubectl delete namespace demo-ansible --ignore-not-found
	-docker rmi $(IMAGE_NAME) --force
	# Optionnel : Supprimer le cluster pour repartir à zéro
	# k3d cluster delete $(CLUSTER_NAME)
	@echo "✨ Propre."

# --- VÉRIFICATION ---
check:
	@echo "🔍 État des pods :"
	kubectl get pods -n demo-ansible

# --- ACCÈS DYNAMIQUE ---
forward:
	@echo "🔀 Recherche d'un port libre entre 8081 et 8090..."
	# On tue les anciens port-forward pour nettoyer
	-pkill -f "kubectl port-forward"
	@for port in $$(seq 8081 8090); do \
		if ! lsof -i :$$port > /dev/null; then \
			echo "✅ Port $$port disponible !"; \
			nohup kubectl port-forward svc/nginx-custom-service $$port:80 -n demo-ansible > /dev/null 2>&1 & \
			echo "🚀 Site accessible sur http://localhost:$$port"; \
			exit 0; \
		else \
			echo "⚠️ Port $$port occupé, essai du suivant..."; \
		fi; \
	done; \
	echo "❌ Aucun port libre trouvé entre 8081 et 8090 !" && exit 1