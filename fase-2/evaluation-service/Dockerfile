FROM golang:1.21-alpine3.19 AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o ./build/evaluation-service .

FROM golang:1.21-alpine3.19 AS base

WORKDIR /app
COPY --from=builder /app/build/evaluation-service /usr/local/bin/evaluation-service
EXPOSE 8004


FROM base AS staging

COPY . .
CMD ["evaluation-service"]


FROM base AS prod

CMD ["evaluation-service"]


