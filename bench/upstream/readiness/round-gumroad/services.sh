#!/usr/bin/env bash
# Gumroad's test services as Amp orb services, with the images and flags of its docker/docker-compose-test-and-ci.yml
# (the ports of docker-compose-ci-runner.yml, which .env.test expects). Docker runs as an orb service too.
#   services.sh up GUMROAD_CHECKOUT    start everything, then create the MinIO buckets and copy the fixtures
#   services.sh down                   stop everything
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
names=(gr-mysql gr-valkey gr-dynamodb gr-es gr-memcached gr-minio)
minio=cgr.dev/chainguard/minio@sha256:bd014394a80898e68c149f2311fdf8d5a2c2f3bb2c33b9327ae6d02b4b065ae1

case "${1:?up|down}" in
  down)
    for n in "${names[@]}" dockerd; do amp orb service stop "$n" || true; done
    ;;
  up)
    app=${2:?GUMROAD_CHECKOUT}
    amp orb service start dockerd --command 'sudo /usr/bin/dockerd'
    for _ in $(seq 30); do [ -S /var/run/docker.sock ] && break; sleep 1; done
    sudo chmod 666 /var/run/docker.sock
    # A 4 GB tmpfs (CI uses 512 MB) because each of the 8 workers has its own database.
    amp orb service start gr-mysql --port 3306 --command 'docker run --rm --name gr-mysql --network host --tmpfs /var/lib/mysql:size=4G -e MYSQL_ROOT_PASSWORD=password mysql:8.4.11 mysqld --mysql-native-password=ON --authentication-policy=*:mysql_native_password --collation-server=utf8mb4_unicode_ci --character-set-server=utf8mb4 --innodb-flush-log-at-trx-commit=0 --innodb-doublewrite=0 --sync-binlog=0 --innodb-flush-method=nosync --skip-log-bin --max-connections=500'
    amp orb service start gr-valkey --port 6379 --command 'docker run --rm --name gr-valkey --network host valkey/valkey:8.1.10 valkey-server --databases 64 --save ""'
    amp orb service start gr-dynamodb --port 8002 --command 'docker run --rm --name gr-dynamodb --network host amazon/dynamodb-local:3.3.1 -jar DynamoDBLocal.jar -inMemory -sharedDb -port 8002'
    amp orb service start gr-es --port 9200 --command 'docker run --rm --name gr-es --network host -e ES_JAVA_OPTS="-Xms1g -Xmx1g" -e discovery.type=single-node elasticsearch:7.9.3'
    amp orb service start gr-memcached --port 11211 --command 'docker run --rm --name gr-memcached --network host memcached:latest'
    amp orb service start gr-minio --port 9000 --command "docker run --rm --name gr-minio --network host --user root -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin $minio server /data --console-address :9001"
    for _ in $(seq 60); do curl -fsS localhost:9000/minio/health/ready >/dev/null 2>&1 && curl -fsS localhost:9200 >/dev/null 2>&1 && break; sleep 2; done
    docker run --rm --network host --entrypoint /bin/sh -v "$here/minio-setup.sh:/setup.sh:ro" \
      -v "$app/spec/support/fixtures:/fixtures:ro" -v "$app/docker/fixture-files-private.txt:/fixture-files-private.txt:ro" \
      -v "$app/docker/fixture-files-public.txt:/fixture-files-public.txt:ro" "$minio" /setup.sh
    ;;
esac
