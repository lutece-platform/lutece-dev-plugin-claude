# Pieges courants de migration V7 → V8

Ce document recense les erreurs reelles rencontrees lors de migrations de sites Lutece. **A lire avant chaque migration.**

Source : `~/Documents/Formation/GitLab/site-support/MIGRATION_LOG.md`

---

## 1. Plugins non actives apres migration

**Symptome :** Le site demarre, mais les XPages retournent "The specified Xpage 'xxx' cannot be retrieved".

**Cause :** En V8, le statut des plugins est dans `core_datastore` (cles `core.plugins.status.<plugin>.installed`). Le fichier `plugins.dat` ne sert qu'au tout premier demarrage.

**Solution :**
- Creer/mettre a jour `WEB-INF/plugins/plugins.dat` avec tous les plugins actifs
- Pour une base existante, inserer directement dans `core_datastore` :
  ```sql
  INSERT INTO core_datastore (entity_key, entity_value) VALUES
  ('core.plugins.status.<plugin>.installed', 'true'),
  ('core.plugins.status.<plugin>.pool', 'portal')
  ON DUPLICATE KEY UPDATE entity_value = VALUES(entity_value);
  ```

**Phase concernee :** Phase 2 (Config)

---

## 2. DataSource server.xml — `properties` vs `properties.mysql`

**Symptome :** Erreur SQL 1045 ou echec de connexion JDBC.

**Cause :** L'element generique `<properties>` ne passe pas correctement les parametres a MySQL. Il faut utiliser `<properties.mysql>` qui est le sous-type specifique MySQL/MariaDB de Liberty.

**Solution :**
```xml
<!-- MAUVAIS -->
<properties serverName="..." databaseName="..." user="..." password="..."/>

<!-- BON -->
<properties.mysql serverName="..." databaseName="..." user="..." password="..."
                  allowPublicKeyRetrieval="true" useSSL="false"/>
```

**Phase concernee :** Phase 2 (Config)

---

## 3. `allowPublicKeyRetrieval` manquant

**Symptome :** Erreur SQL 1045 "Access denied" meme avec les bons identifiants.

**Cause :** MySQL 8+ utilise par defaut `caching_sha2_password`. Sans `allowPublicKeyRetrieval=true`, le client ne peut pas negocier l'authentification.

**Solution :** Ajouter `allowPublicKeyRetrieval="true"` dans `<properties.mysql>` du server.xml, ou dans l'URL JDBC de db.properties.

**Phase concernee :** Phase 2 (Config)

---

## 4. `portal.ds` vs `portal.jndiname`

**Symptome :** Erreur JNDI "DataSource not found" au demarrage.

**Cause :** La propriete correcte dans db.properties est **`portal.ds`**, pas `portal.jndiname` (qui etait utilise dans certaines anciennes versions).

**Solution :**
```properties
# MAUVAIS
portal.jndiname=jdbc/portal

# BON
portal.ds=jdbc/portal
```

Le `portal.ds` doit correspondre exactement au `jndiName` dans `<dataSource>` du server.xml.

**Phase concernee :** Phase 2 (Config)

---

## 5. Nom de base de donnees incorrect dans server.xml

**Symptome :** NullPointerException, erreur 500, ou `Portlet.getColumn()` null.

**Cause :** Le `databaseName` dans server.xml ne correspond pas au nom reel de la base (ex: `support` au lieu de `site_support`).

**Solution :** Verifier le nom exact de la base avec :
```sql
SHOW DATABASES;
```
Et s'assurer qu'il correspond dans server.xml **et** dans db.properties.

**Phase concernee :** Phase 2 (Config)

---

## 6. CSS/JS manquants apres suppression de plugins

**Symptome :** Layout casse, styles absents apres migration.

**Cause :** Les plugins supprimes (ex: `site-theme-wiki`) fournissaient des fichiers CSS/JS. Les templates y font encore reference.

**Solution :**
1. Avant de supprimer un plugin, lister les fichiers statiques qu'il fournit
2. Verifier si des templates font reference a ces fichiers
3. Creer des copies locales dans `webapp/css/` ou `webapp/js/` si necessaire

**Phase concernee :** Phase 1 (POM) + Phase 3 (Templates)

---

## 7. plugin-html manquant (ClassNotFoundException)

**Symptome :** `ClassNotFoundException: HtmlPortletHome` au demarrage.

**Cause :** Le plugin `plugin-html` est souvent une dependance implicite (utilisee par d'autres plugins) mais pas listee explicitement dans le POM V7.

**Solution :** Si le site utilise des portlets HTML, ajouter explicitement :
```xml
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>plugin-html</artifactId>
    <type>lutece-plugin</type>
</dependency>
```

**Phase concernee :** Phase 0 (Scan) + Phase 1 (POM)

---

## 8. Suppression de `theme.globalThemeCode` (NPE front-office)

**Symptome :** NullPointerException sur le front-office apres nettoyage de la base.

**Cause :** La cle `theme.globalThemeCode` dans `core_datastore` est utilisee par le **CORE** (`ThemeDAO.getGlobalTheme()`), PAS par plugin-theme. Un `DELETE FROM core_datastore WHERE entity_key LIKE 'theme.%'` la supprime par erreur.

**Solution :** Ne JAMAIS supprimer cette cle. Liste des cles datastore protegees :
- `theme.globalThemeCode` — theme actif du front-office
- `portal.theme.*` — configuration theme du core
- `core.*` — configuration systeme du core
- `core.plugins.status.*` — ne supprimer que pour les plugins reellement retires

Le script `generate-upgrade-sql.sh` protege automatiquement ces cles.

**Phase concernee :** Phase 2 (Config / SQL upgrade)

---

## 9. References orphelines a plugin-extend dans les templates

**Symptome :** Erreurs Freemarker silencieuses ou inclusions vides apres suppression de plugin-extend.

**Cause :** Les templates referent souvent des macros extend (`<@extendAction>`, `<@extendComment>`, `<#include "*/extend/*">`). Quand le plugin est supprime, les macros ne sont plus definies.

**Solution :** Rechercher et supprimer toutes les references extend dans les templates :
```
grep -r "extend" webapp/WEB-INF/templates/
```

**Phase concernee :** Phase 3 (Templates)

---

## 10. Application entry dans server.xml en mode dev

**Symptome :** Warning `CWWKZ0014W` dans les logs — l'application `lutece.war` n'est pas trouvee.

**Cause :** En mode dev (`mvn liberty:dev`), le liberty-maven-plugin deploie l'app via un mecanisme loose-archive (`.war.xml` dans les dropins). L'entree `<application location="lutece.war">` dans server.xml cherche un fichier WAR qui n'existe pas.

**Solution :**
- Ignorer le warning (pas bloquant)
- Ou commenter l'entree `<application>` en mode dev
- Ou utiliser le bon nom : `<application name="site-xxx" context-root="site-xxx" .../>`

**Phase concernee :** Phase 2 (Config)

---

## Checklist post-demarrage

Apres le premier demarrage du site migre, verifier :

- [ ] Front-office accessible (HTTP 200)
- [ ] Back-office accessible (HTTP 200)
- [ ] Toutes les XPages fonctionnent (pas de "cannot be retrieved")
- [ ] Pas d'erreur dans les logs serveur
- [ ] CSS/JS charges correctement (pas de 404 dans la console navigateur)
- [ ] Les plugins sont tous actifs dans l'admin (Systeme > Gestion des plugins)
