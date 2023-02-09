FROM mariadb:10.5

RUN rm -rf /etc/mysql/*

COPY ./my.cnf /etc/mysql/my.cnf

COPY ./scripts /code

RUN chmod +x /code/* \
  && chown mysql:mysql "/etc/mysql/my.cnf" \
  && chown -R mysql:mysql "/code"

