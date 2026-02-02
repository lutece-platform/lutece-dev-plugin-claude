-- liquibase formatted sql
-- changeset referencelist:update_db_referencelist-1.0.1-1.0.2.sql
-- preconditions onFail:MARK_RAN onError:WARN

--
-- Refactor table referencelist_item
--
ALTER TABLE referencelist_item ADD COLUMN name long varchar;
ALTER TABLE referencelist_item ADD COLUMN code long varchar;
UPDATE referencelist_item SET name = item_name, code = item_value WHERE id_reference_item >= 0;
ALTER TABLE referencelist_item DROP COLUMN item_name;
ALTER TABLE referencelist_item DROP COLUMN item_value;

--
-- Structure for table referencelist_translation
--
DROP TABLE IF EXISTS referencelist_translation;
CREATE TABLE referencelist_translation (
	id_translation int AUTO_INCREMENT,
	lang varchar(10) NOT NULL,
	name long varchar NOT NULL,
	id_reference_item int NOT NULL,
	PRIMARY KEY (id_translation)
);
