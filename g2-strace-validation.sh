set -eu

mariadb \
  --protocol=TCP \
  --host=mariadb-galera.database.svc.cluster.local \
  --port=3306 \
  --user=migrationuser \
  --password="$MIGRATION_PASSWORD" \
  appdb <<'SQL'

SELECT CURRENT_USER() AS authenticated_as;
SELECT DATABASE() AS current_database;
SELECT @@hostname AS connected_to;

DROP TABLE IF EXISTS g2_migration_test;
SELECT 'Initial cleanup successful' AS step;

CREATE TABLE g2_migration_test (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

SELECT 'CREATE TABLE successful' AS step;

ALTER TABLE g2_migration_test
  ADD COLUMN created_at TIMESTAMP
  NOT NULL DEFAULT CURRENT_TIMESTAMP;

SELECT 'ALTER TABLE successful' AS step;

CREATE INDEX idx_g2_name
ON g2_migration_test (name);

SELECT 'CREATE INDEX successful' AS step;

DROP INDEX idx_g2_name
ON g2_migration_test;

SELECT 'DROP INDEX successful' AS step;

DROP TABLE g2_migration_test;
SELECT 'Final cleanup successful' AS step;

SQL
