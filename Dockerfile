# syntax=docker/dockerfile:1
# Build stage
FROM golang:alpine AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ENV CGO_ENABLED=0
RUN go build -o rspamd-iscan main.go

# Runtime stage
FROM alpine

# update upgrade
RUN apk update && apk upgrade --no-cache

RUN apk --no-cache add ca-certificates

COPY --from=builder /build/rspamd-iscan /usr/local/bin/rspamd-iscan

# Default config path - mount your config.toml here
RUN mkdir -p /etc/rspamd-iscan

USER nobody

ENTRYPOINT ["/usr/local/bin/rspamd-iscan"]
CMD ["--cfg-file", "/etc/rspamd-iscan/config.toml"]
