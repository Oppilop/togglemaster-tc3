# Stage 1: Build
FROM golang:1.22 AS builder

# Definir diretório de trabalho
WORKDIR /app

# Copiar arquivos de dependência primeiro (para cache eficiente)
COPY go.mod go.sum ./
RUN go mod download

# Copiar o restante do código
COPY . .

# Compilar o binário
RUN go build -o auth-service .

# Stage 2: Runtime
FROM alpine:3.19

WORKDIR /app

# Copiar apenas o binário compilado
COPY --from=builder /app/auth-service .

# Variáveis de ambiente (ajuste conforme necessário)
ENV DB_HOST=postgres-auth
ENV DB_USER=auth
ENV DB_PASSWORD=authpass
ENV DB_NAME=authdb

# Expor a porta
EXPOSE 8080

# Comando de inicialização
CMD ["./auth-service"]

