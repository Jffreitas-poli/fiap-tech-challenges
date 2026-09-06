FROM golang:1.25-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/evaluation-service .

# runtime minimo: so o binario, sem o toolchain Go (evita CVEs do stdlib/tooling na imagem final)
FROM alpine:3.21 AS base

RUN apk add --no-cache ca-certificates \
    && adduser -D -u 1000 app
USER app
WORKDIR /app
COPY --from=builder /out/evaluation-service /usr/local/bin/evaluation-service
EXPOSE 8004


FROM base AS staging
CMD ["evaluation-service"]


FROM base AS prod
CMD ["evaluation-service"]
