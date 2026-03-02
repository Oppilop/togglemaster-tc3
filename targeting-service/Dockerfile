# Stage 1: Build (instala dependências)
FROM python:3.11-slim AS builder

WORKDIR /app

# Copiar dependências primeiro
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

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

