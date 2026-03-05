# Stage 1: Build (instala dependências)
FROM python:3.11-slim AS builder

WORKDIR /app

# Copiar dependências primeiro
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Instalar curl/wget na imagem final
RUN apt-get update && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar código da aplicação
COPY . .

# Copiar dependências do builder
COPY --from=builder /root/.local /root/.local

# Ajustar PATH para encontrar os pacotes instalados
ENV PATH=/root/.local/bin:$PATH

# Expor a porta
EXPOSE 8003

# Comando de inicialização
CMD ["python", "app.py"]

# Healthcheck para verificação do serviço
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \ 
    CMD curl -f http://localhost:8003/health || exit 1