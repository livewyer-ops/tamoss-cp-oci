DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'The bootstrap test must use a non-superuser';
  END IF;
  IF NOT has_database_privilege('tams', 'tams', 'CONNECT')
     OR NOT has_database_privilege('authentik', 'authentik', 'CONNECT')
     OR has_database_privilege('authentik', 'tams', 'CONNECT')
     OR has_database_privilege('tams', 'authentik', 'CONNECT') THEN
    RAISE EXCEPTION 'Application database isolation failed';
  END IF;
  IF NOT has_database_privilege('tadoss', 'tadoss', 'CONNECT')
     OR has_database_privilege('tadoss', 'tams', 'CONNECT')
     OR has_database_privilege('tadoss', 'authentik', 'CONNECT')
     OR has_database_privilege('tams', 'tadoss', 'CONNECT')
     OR has_database_privilege('authentik', 'tadoss', 'CONNECT') THEN
    RAISE EXCEPTION 'TADOSS database isolation failed';
  END IF;
END $$;
\connect tams tams
SELECT current_user;
\connect authentik authentik
SELECT current_user;
\connect tadoss tadoss
CREATE EXTENSION IF NOT EXISTS btree_gist;
SELECT current_user;
