# Site Migration Verification Checks

Single source of truth for all site migration grep checks. Consumed by:
- `scripts/verify-site-migration.sh` (implements all checks)
- Phase 5 (runs the script)

Each check has: ID, category, pattern, search path, severity, and description.

---

## POM Dependencies

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| PM01 | `org\.springframework` | `pom.xml` | FAIL | Spring dependencies must be removed |
| PM02 | `net\.sf\.ehcache` | `pom.xml` | FAIL | EhCache dependencies must be removed |
| PM03 | `com\.sun\.mail` | `pom.xml` | FAIL | javax.mail dependency must be removed |
| PM04 | `org\.glassfish\.jersey` | `pom.xml` | FAIL | Jersey dependencies must be removed |
| PM05 | `net\.sf\.json-lib` | `pom.xml` | WARN | Use Jackson instead |
| PM06 | Parent `<version>` != `8.0.0-SNAPSHOT` | `pom.xml` | FAIL | Parent version must be `8.0.0-SNAPSHOT` |
| PM07 | `<springVersion>` | `pom.xml` | FAIL | springVersion property must be removed |

---

## Spring Residues

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| SP03 | `*_context.xml` files exist | `webapp/` | FAIL | Spring context XML files must be deleted |
| WB03 | `ContextLoaderListener` | `webapp/` | FAIL | Spring listener must be removed from web.xml |

---

## Web / Config

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| WB01 | `java\.sun\.com/xml/ns/javaee` | `webapp/` | FAIL | Must be `jakarta.ee/xml/ns/jakartaee` |
| WB05 | `com\.mysql\.jdbc\.Driver` | `db.properties` | WARN | Use `com.mysql.cj.jdbc.Driver` |

---

## Templates

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| TM01 | `class="panel` | `webapp/WEB-INF/templates/` | WARN | Old Bootstrap panels → BS5 cards |
| TM02 | `jQuery\|\$(` | `webapp/WEB-INF/templates/` | FAIL | jQuery in templates → vanilla JS |
| TM03 | `jQuery\|\$(` | `webapp/js/` | FAIL | jQuery in JS files → vanilla JS |
| TM04 | `data-toggle=\|data-target=\|data-dismiss=` | `webapp/WEB-INF/templates/` | WARN | BS3/4 data attributes → `data-bs-*` (BS5) |
| TM05 | `jquery\.min\.js\|jquery\.js\|jquery-[0-9]` | `webapp/WEB-INF/templates/` | FAIL | jQuery script includes must be removed |
| TM06 | `datepicker\|\.DataTable\|select2\|\.autocomplete` | `webapp/WEB-INF/templates/` | WARN | jQuery plugins → vanilla alternatives |
| TM07 | Skin template without `<@cTpl>` | `webapp/WEB-INF/templates/skin/` | WARN | All skin templates need `<@cTpl>` wrapper |

---

## SQL

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| SQ01 | SQL file without `liquibase formatted sql` header | `*.sql` | WARN | All SQL files should have Liquibase headers |

---

## Summary

- **Total checks**: 18
- **FAIL severity**: 10 (will break site assembly or runtime)
- **WARN severity**: 8 (best practice, should fix)
