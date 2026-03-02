# Stage 1: Build
FROM golang:1.22 AS builder

WORKDIR /app

# Copiar dependências primeiro
COPY go.mod go.sum ./
RUN go mod download

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

