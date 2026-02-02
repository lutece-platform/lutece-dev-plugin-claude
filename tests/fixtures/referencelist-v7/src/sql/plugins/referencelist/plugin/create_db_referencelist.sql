-- liquibase formatted sql
-- changeset referencelist:create_db_referencelist.sql
-- preconditions onFail:MARK_RAN onError:WARN

--
-- Structure for table referencelist_reference
--

DROP TABLE IF EXISTS referencelist_reference;
CREATE TABLE referencelist_reference (
id_reference int AUTO_INCREMENT ,
name long varchar NOT NULL,
description long varchar NOT NULL,
PRIMARY KEY (id_reference)
);

--
-- Structure for table referencelist_item
--

DROP TABLE IF EXISTS referencelist_item;
CREATE TABLE referencelist_item (
id_reference_item int AUTO_INCREMENT,
name long varchar NOT NULL,
code long varchar NOT NULL,
idreference int default '0' NOT NULL,
PRIMARY KEY (id_reference_item)
);

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
