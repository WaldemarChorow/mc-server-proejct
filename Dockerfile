FROM eclipse-temurin:21-jre

WORKDIR /app

COPY server.jar .

# Automatically accept Minecraft EULA
RUN echo "eula=true" > eula.txt

EXPOSE 25565

# Start script using curly braces for environment variables
CMD ["sh", "-c", "java -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} -jar server.jar nogui"]