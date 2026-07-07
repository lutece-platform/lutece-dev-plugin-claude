-- Runs AFTER the Liquibase init (i.e. after app1/migrator is healthy).
-- Clears the default admin "expired password" wall, so one can
-- log in as admin/adminadmin without the password-change screen.
UPDATE core_admin_user
   SET reset_password = 0,
       password_max_valid_date = '2099-01-01 00:00:00'
 WHERE access_code = 'admin';

-- dbinit re-runs on EVERY `docker compose up -d` -> keep everything IDEMPOTENT.

-- FO user seed — uncomment when the flow under test needs a logged-in LuteceUser
-- (see harness README "FO authentication"). Adapt the role_key.
-- INSERT IGNORE INTO mylutece_database_user
--   (mylutece_database_user_id, login, password, name_given, name_family, email, is_active)
-- VALUES (1000, 'test', 'PLAINTEXT:testtest', 'Test', 'User', 'test@example.com', 1);
-- INSERT IGNORE INTO mylutece_database_user_role (mylutece_database_user_id, role_key)
-- VALUES (1000, '<role_needed_by_the_plugin>');
