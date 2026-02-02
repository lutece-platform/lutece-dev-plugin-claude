-- liquibase formatted sql
-- changeset referencelist:update_db_referencelist-1.0.2-2.0.0.sql
-- preconditions onFail:MARK_RAN onError:WARN
UPDATE core_admin_right SET icon_url='ti ti-list-details' WHERE id_right='REFERENCELIST_MANAGEMENT';