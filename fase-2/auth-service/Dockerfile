FROM golang:1.25-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/auth-service .

# runtime minimo: so o binario, sem o toolchain Go (evita CVEs do stdlib/tooling na imagem final)
FROM alpine:3.21 AS base

RUN apk add --no-cache ca-certificates \
    && adduser -D -u 1000 app
USER app
WORKDIR /app
COPY --from=builder /out/auth-service /usr/local/bin/auth-service
EXPOSE 8001


FROM base AS staging
CMD ["auth-service"]


FROM base AS prod
CMD ["auth-service"]
