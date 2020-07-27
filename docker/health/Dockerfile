FROM alpine

RUN apk add curl && apk add iputils
RUN apk add openssl

ADD ./health.sh /health.sh
CMD /health.sh
