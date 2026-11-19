\getenv tams_password TAMS_PASSWORD
\getenv authentik_password AUTHENTIK_PASSWORD
SELECT 'CREATE ROLE tams LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tams')\gexec
SELECT 'CREATE ROLE authentik LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authentik')\gexec
SELECT format('ALTER ROLE tams PASSWORD %L', :'tams_password')\gexec
SELECT format('ALTER ROLE authentik PASSWORD %L', :'authentik_password')\gexec
SELECT format('GRANT tams, authentik TO %I', current_user)\gexec
SELECT 'CREATE DATABASE tams OWNER tams' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tams')\gexec
SELECT 'CREATE DATABASE authentik OWNER authentik' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'authentik')\gexec
REVOKE ALL ON DATABASE tams FROM PUBLIC;
REVOKE ALL ON DATABASE authentik FROM PUBLIC;
