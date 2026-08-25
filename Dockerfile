FROM eclipse-temurin:25-jre

ARG MC_VERSION
ARG MC_SERVER_URL

WORKDIR /app
RUN curl -fsSL -o server.jar "${MC_SERVER_URL}"

EXPOSE 25565

WORKDIR /data
RUN echo "eula=true" > eula.txt

CMD ["sh", "-c", "java -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} -jar /app/server.jar nogui"]
