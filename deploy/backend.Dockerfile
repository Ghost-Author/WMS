FROM maven:3.9.16-eclipse-temurin-17 AS builder

WORKDIR /workspace
COPY . .
RUN mvn -B -ntp -pl ruoyi-admin -am clean package -DskipTests

FROM eclipse-temurin:17-jre-noble

WORKDIR /app
COPY --from=builder --chown=10001:10001 /workspace/ruoyi-admin/target/ruoyi-admin.jar /app/app.jar
RUN mkdir -p /app/data/uploadPath /app/data/logs && chown -R 10001:10001 /app

USER 10001:10001
EXPOSE 8080

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/urandom", "-jar", "/app/app.jar"]
