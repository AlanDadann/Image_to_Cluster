# Variables
CLUSTER_NAME=lab
IMAGE_NAME=nginx-custom:latest
# Cette variable résout automatiquement le problème de chemin Python pour Ansible
PYTHON_PATH=$(shell which python3)

# La liste des commandes disponibles
.PHONY: all install build import deploy clean check

# Par défaut, si on tape juste "make", on lance tout
all: build import deploy

# --- 1. INSTALLATION DES OUTILS ---
install:
	@echo "🛠️ Installation des dépendances..."
	sudo apt-get update && sudo apt-get install -y packer ansible
	$(PYTHON_PATH) -m pip install kubernetes
	ansible-galaxy collection install kubernetes.core
	@echo "✅ Tout est installé."

# --- 2. BUILD PACKER ---
build:
	@echo "🏗️ Construction de l'image Docker avec Packer..."
	packer init build.pkr.hcl
	packer build build.pkr.hcl

# --- 3. IMPORT DANS K3D ---
import:
	@echo "📦 Import de l'image dans le cluster K3d..."
	k3d image import $(IMAGE_NAME) -c $(CLUSTER_NAME)

# --- 4. DÉPLOIEMENT ANSIBLE ---
deploy:
	@echo "🚀 Déploiement avec Ansible..."
	# On passe explicitement le chemin de python pour éviter l'erreur de librairie manquante
	ansible-playbook deploy.yml -e "ansible_python_interpreter=$(PYTHON_PATH)"

# --- 5. NETTOYAGE (Optionnel) ---
clean:
	@echo "🧹 Nettoyage complet..."
	kubectl delete namespace demo-ansible --ignore-not-found
	-docker rmi nginx-custom:latest --force
	@echo "✨ Environnement propre."

# --- 6. TEST RAPIDE ---
check:
	@echo "🔍 Vérification des pods..."
	kubectl get pods -n demo-ansible