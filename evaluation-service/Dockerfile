# Stage 1: Build
FROM golang:1.22 AS builder

WORKDIR /app

# Copiar dependências primeiro
COPY go.mod go.sum ./
RUN go mod download
RUN apt-get update && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar todo o código
COPY . .

# Compilar o binário (build estático para rodar em Alpine)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o evaluation-service .

# Stage 2: Runtime
FROM alpine:3.19

WORKDIR /app

# Copiar binário do builder
COPY --from=builder /app/evaluation-service .

# Expor a porta
EXPOSE 8004

# Comando de inicialização
CMD ["./evaluation-service"]

# Healthcheck para verificação do serviço
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8004/health || exit 1