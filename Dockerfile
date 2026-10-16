FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    lftp \
    curl \
    iputils \
    tzdata

WORKDIR /app

COPY src/ ./src/
RUN chmod +x ./src/*.sh

CMD ["./src/sync.sh"]
