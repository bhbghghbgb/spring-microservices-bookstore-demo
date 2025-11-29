docker run --rm \
  -v $(pwd)/databases/mongo-data:/backup/mongo-data:ro \
  -v $(pwd)/databases/postgres-order:/backup/postgres-order:ro \
  -v $(pwd)/databases/postgres-stock-check:/backup/postgres-stock-check:ro \
  -v $(pwd)/databases/postgres-author:/backup/postgres-author:ro \
  -v $(pwd)/databases/pgadmin-data:/backup/pgadmin-data:ro \
  -v $(pwd)/grafana:/backup/grafana:ro \
  -v $(pwd)/data/backups:/archive \
  --entrypoint backup \
  offen/docker-volume-backup:v2.46.1 \
