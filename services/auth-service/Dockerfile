# Stage 1: Build
FROM golang:1.24.0 AS builder

# Definir diretório de trabalho
WORKDIR /app

# Copiar arquivos de dependência primeiro (para cache eficiente)
COPY go.mod go.sum ./
RUN go mod download
RUN apt-get update && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar o restante do código
COPY . .

# Compilar o binário
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o auth-service .

# Stage 2: Runtime
FROM alpine:3.19

WORKDIR /app

# Copiar apenas o binário compilado
COPY --from=builder /app/auth-service .

# Expor a porta
EXPOSE 8001

# Comando de inicialização
CMD ["./auth-service"]

# Healthcheck para verificação do serviço
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8001/health || exit 1
