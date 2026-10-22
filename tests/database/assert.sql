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
END $$;
\connect tams tams
SELECT current_user;
\connect authentik authentik
SELECT current_user;
