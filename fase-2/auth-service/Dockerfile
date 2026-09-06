FROM golang:1.21-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o ./build/auth-service .

FROM golang:1.21-alpine AS base

WORKDIR /app
COPY --from=builder /app/build/auth-service /usr/local/bin/auth-service
EXPOSE 8001


FROM base AS staging

COPY . .
CMD ["auth-service"]


FROM base AS prod

CMD ["auth-service"]
