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

# Variáveis de ambiente (ajuste conforme necessário)
ENV DB_HOST=postgres-flag
ENV DB_USER=flag
ENV DB_PASSWORD=flagpass
ENV DB_NAME=flagdb

# Expor a porta
EXPOSE 8004

# Comando de inicialização
CMD ["python", "app.py"]
