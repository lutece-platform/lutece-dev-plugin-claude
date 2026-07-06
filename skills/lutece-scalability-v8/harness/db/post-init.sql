-- Runs AFTER the Liquibase init (i.e. after app1/migrator is healthy).
-- Clears the default admin "expired password" wall, so one can
-- log in as admin/adminadmin without the password-change screen.
UPDATE core_admin_user
   SET reset_password = 0,
       password_max_valid_date = '2099-01-01 00:00:00'
 WHERE access_code = 'admin';
