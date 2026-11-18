# syntax=docker/dockerfile:1
#
# Polyrepo — the build context is this repository alone. spendwise-parent,
# spendwise-common and spendwise-events come from GitHub Packages, so the
# build stage needs a token. It arrives as a BuildKit secret: mounted only for
# the RUN that needs it, never written to a layer or the image history.
#
#   docker build --secret id=gh_token,env=GITHUB_PACKAGES_TOKEN -t spendwise-user-service .
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY ci-settings.xml pom.xml ./
COPY src src
RUN --mount=type=cache,target=/root/.m2/repository \
    --mount=type=secret,id=gh_token,env=GITHUB_PACKAGES_TOKEN,required=true \
    mvn -B -ntp -s ci-settings.xml -DskipTests clean package

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"
RUN addgroup -S spendwise && adduser -S -G spendwise spendwise
COPY --from=build /workspace/target/*.jar app.jar
RUN chown spendwise:spendwise app.jar
USER spendwise
EXPOSE 8082
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8082/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
