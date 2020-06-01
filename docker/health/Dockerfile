FROM alpine

RUN apk add curl && apk add iputils && apk add jq

ADD ./health.sh /health.sh
CMD /health.sh