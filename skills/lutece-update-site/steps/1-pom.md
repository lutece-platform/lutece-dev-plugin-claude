# Step 1 — The pom

Rules and their evidence: `reference/layers.md`. Codes: SI01-SI09.

1. Parent: `lutece-site-pom` at `V8_FLOOR_SITE_PARENT` of `tools/v8-floor.conf` or later, the latest released 8.x
   (`https://dev.lutece.paris.fr/maven_repository/fr/paris/lutece/tools/lutece-site-pom/maven-metadata.xml`).
2. `dependencyManagement`: one import of `fr.paris.lutece.starters:lutece-bom` (type pom, scope import), the version
   of phase B's gate.
3. The layer of phase C: the pack (`<type>lutece-site</type>`, a fixed version) or the starter (a fixed version, the
   BOM's). A v7 theme or pack is replaced by its successor (`tools/site-successors.tsv`).
4. Every other plugin of the decisions file marked "declared by the site": without version when the BOM manages it,
   with the `<type>` the BOM gives (`lutece-plugin`, `jar`), otherwise with the fixed version the gate printed.
5. Remove: `lutece-core`, the versions and ranges of managed artefacts, the `lutece.*.version` properties, the
   profiles with `defaultConfDirectory` (their content moves in step 2), the `http://` repositories (the parent
   declares `https://`), any artefact the layer already brings.
6. A Maven profile `local` that makes `library-configsource-vault` `provided`, when developers run the site without
   a Vault, is a choice of the site: keep it out of the default build.

Then `tools/site-assemble.sh . --out target/check --repo .migration/m2` and `mvn -q help:effective-pom` must succeed
before step 2: the enforcer (`requireUpperBoundDeps`) runs in the build.
