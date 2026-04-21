# Variáveis
CLUSTER_FILE=cluster.yaml
REGION=us-east-1
CLUSTER_NAME=togglemaster-eks-prod

.PHONY: all setup-cluster apply-jobs apply-namespaces-db apply-namespaces apply-services clean

# Comando principal que executa tudo na ordem
all: setup-cluster apply-jobs apply-namespaces-db apply-namespaces apply-services

# 1. Criar o cluster do EKS
setup-cluster:
	@echo "Iniciando criação do cluster EKS... Isso pode levar 15-20 min."
	eksctl create cluster -f $(CLUSTER_FILE)

# 2. Aplicar os jobs
apply-jobs:
	@echo "Aplicando Jobs de configuração inicial..."
	kubectl apply -f auth-job.yaml
	kubectl apply -f flag-job.yaml
	kubectl apply -f targeting-job.yaml

# 3. Aplicar os namespaces
apply-namespaces-db:
	@echo "Criando Namespaces..."
	kubectl apply -f auth-namespace.yaml
	kubectl apply -f flag-namespace.yaml
	kubectl apply -f targeting-namespace.yaml
	kubectl apply -f evaluation-namespace.yaml
	kubectl apply -f analytics-namespace.yaml

# 4. Aplicar os services (Deployments/Services/Configs)
apply-services-db:
	@echo "Fazendo deploy dos microserviços db..."
	kubectl apply -f auth-service.yaml
	kubectl apply -f flag-service.yaml
	kubectl apply -f targeting-service.yaml

# 5. Aplicar os services (Deployments/Services/Configs)
apply-services:
	@echo "Fazendo deploy dos microserviços..."
	kubectl apply -f evaluation-service.yaml
	kubectl apply -f analytics-service.yaml
