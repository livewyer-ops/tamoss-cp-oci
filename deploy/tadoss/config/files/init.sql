\getenv tadoss_password TADOSS_PASSWORD
SELECT 'CREATE ROLE tadoss LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tadoss')\gexec
SELECT format('ALTER ROLE tadoss PASSWORD %L', :'tadoss_password')\gexec
SELECT format('GRANT tadoss TO %I', current_user)\gexec
SELECT 'CREATE DATABASE tadoss OWNER tadoss' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tadoss')\gexec
REVOKE ALL ON DATABASE tadoss FROM PUBLIC;
