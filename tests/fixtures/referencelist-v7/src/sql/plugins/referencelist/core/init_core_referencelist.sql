-- liquibase formatted sql
-- changeset referencelist:init_core_referencelist.sql
-- preconditions onFail:MARK_RAN onError:WARN

--
-- Data for table core_admin_right
--
DELETE FROM core_admin_right WHERE id_right = 'REFERENCELIST_MANAGEMENT';
INSERT INTO core_admin_right (id_right,name,level_right,admin_url,description,is_updatable,plugin_name,id_feature_group,icon_url,documentation_url, id_order ) VALUES 
('REFERENCELIST_MANAGEMENT','referencelist.adminFeature.ReferenceListManage.name',1,'jsp/admin/plugins/referencelist/ManageReferences.jsp','referencelist.adminFeature.ReferenceListManage.description',0,'referencelist',NULL,NULL,NULL,4);

--
-- Data for table core_user_right
--
DELETE FROM core_user_right WHERE id_right = 'REFERENCELIST_MANAGEMENT';
INSERT INTO core_user_right (id_right,id_user) VALUES ('REFERENCELIST_MANAGEMENT',1);

INSERT INTO core_admin_role_resource (role_key,resource_type,resource_id,permission) VALUES ('CREATE_REFERENCE_IMPORT', 'REFERENCE_IMPORT', '*', '*');


--
-- Data for table core_admin_role
--
INSERT INTO core_admin_role VALUES ('CREATE_REFERENCE_IMPORT','Import csv file');
INSERT INTO core_user_role VALUES ('CREATE_REFERENCE_IMPORT',1);