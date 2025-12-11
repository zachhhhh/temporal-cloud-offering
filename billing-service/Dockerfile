FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o billing-service .

FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /srv
COPY --from=builder /app/billing-service /usr/local/bin/billing-service

EXPOSE 8082

CMD ["/usr/local/bin/billing-service"]
