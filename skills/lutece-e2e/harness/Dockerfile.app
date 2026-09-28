# Open Liberty runtime on Eclipse Temurin (HotSpot). Chosen over the official OpenJ9 images because the
# bench needs a complete, stable JFR (OpenJ9 0.61 asserts in the VM under JFR sampling) plus jcmd for
# on-demand recordings. The Liberty version is pinned; the zip comes from Maven Central.
FROM eclipse-temurin:21-jdk-noble
ARG LIBERTY_VERSION=26.0.0.9
RUN curl -fsSL -o /tmp/ol.zip "https://repo1.maven.org/maven2/io/openliberty/openliberty-runtime/${LIBERTY_VERSION}/openliberty-runtime-${LIBERTY_VERSION}.zip" \
 && cd /opt && jar xf /tmp/ol.zip && rm /tmp/ol.zip && chmod -R a+x /opt/wlp/bin \
 && /opt/wlp/bin/server create defaultServer && mkdir -p /logs /opt/wlp/output
ENV WLP_OUTPUT_DIR=/opt/wlp/output LOG_DIR=/logs PATH="/opt/wlp/bin:${PATH}"
COPY liberty/server.xml  /opt/wlp/usr/servers/defaultServer/server.xml
COPY liberty/jvm.options /opt/wlp/usr/servers/defaultServer/jvm.options
COPY liberty/server.env  /opt/wlp/usr/servers/defaultServer/server.env
COPY site/target/lutece.war /opt/wlp/usr/servers/defaultServer/apps/lutece.war
# The JDBC driver must exist before the war is expanded (the dataSource is resolved first): extract it.
RUN mkdir -p /opt/wlp/usr/shared/resources/jdbc \
 && cd /tmp && jar xf /opt/wlp/usr/servers/defaultServer/apps/lutece.war WEB-INF/lib \
 && cp WEB-INF/lib/mariadb-java-client-*.jar WEB-INF/lib/postgresql-*.jar /opt/wlp/usr/shared/resources/jdbc/ 2>/dev/null; rm -rf /tmp/WEB-INF \
 && ls /opt/wlp/usr/shared/resources/jdbc
# Bench runs as the host user (compose `user:`): the server tree must stay writable for any uid.
RUN chmod -R a+rwX /opt/wlp/usr/servers /opt/wlp/output /logs
EXPOSE 9090
CMD ["server", "run", "defaultServer"]
