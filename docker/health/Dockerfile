FROM alpine

RUN apk add curl && apk add iputils

ADD ./health.sh /health.sh
CMD /health.sh