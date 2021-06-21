FROM mariadb

USER root

RUN apt-get update

RUN apt-get install -y liblz4-dev
RUN apt-get install -y mariadb-plugin-rocksdb

RUN rm -rf /var/cache/apt/lists/*


