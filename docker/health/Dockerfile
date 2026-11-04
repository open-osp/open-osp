FROM alpine

RUN apk add --no-cache curl mariadb-client

ADD ./health.sh /health.sh
CMD ["sh", "/health.sh"]
