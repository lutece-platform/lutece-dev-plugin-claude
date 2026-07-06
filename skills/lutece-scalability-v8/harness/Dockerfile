# Liberty "full" image: bundles mpTelemetry-2.0 / mpHealth-4.0 / restfulWS-3.1
# required by the server.xml featureManager.
FROM icr.io/appcafe/open-liberty:full-java21-openj9-ubi-minimal
USER root

# Liberty config (deploys lutece.war + dataSource jdbc/portal)
COPY src/main/liberty/config/server.xml  /config/server.xml
COPY src/main/liberty/config/server.env  /config/server.env
COPY src/main/liberty/config/jvm.options /config/jvm.options
COPY hazelcast.xml                        /config/hazelcast.xml
COPY hazelcast-session.xml                /config/hazelcast-session.xml
COPY hazelcast-5.5.0.jar                   /config/hazelcast/hazelcast-5.5.0.jar

# Packaged application (produced by gen-test-site.sh)
COPY target/lutece.war  /config/apps/lutece.war

# Shared volume folders (mounted at runtime by compose)
RUN mkdir -p /opt/lutece/shared/forms-index /opt/lutece/shared/filestore \
 && chown -R 1001:0 /opt/lutece/shared

USER 1001
RUN configure.sh
EXPOSE 9090 9443
