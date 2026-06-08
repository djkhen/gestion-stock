# =====================================================================
#  Dockerfile multi-stage pour le backend Quarkus (mode JVM)
#  Stage 1 : on compile avec Maven (pas besoin de Maven sur la machine !)
#  Stage 2 : image légère qui exécute juste le résultat (le "fast-jar")
# =====================================================================

# ---------- Stage 1 : build ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# On copie d'abord le pom seul pour profiter du cache de dépendances Docker :
# tant que le pom ne change pas, cette couche est réutilisée.
COPY pom.xml .
RUN mvn -B dependency:go-offline

# Puis le code source et on package (les tests sont ignorés ici)
COPY src ./src
RUN mvn -B clean package -DskipTests

# ---------- Stage 2 : runtime ----------
FROM eclipse-temurin:21-jre
WORKDIR /app

# Quarkus produit un "fast-jar" réparti en plusieurs dossiers dans target/quarkus-app
COPY --from=build /app/target/quarkus-app/lib/ ./lib/
COPY --from=build /app/target/quarkus-app/*.jar ./
COPY --from=build /app/target/quarkus-app/app/ ./app/
COPY --from=build /app/target/quarkus-app/quarkus/ ./quarkus/

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
