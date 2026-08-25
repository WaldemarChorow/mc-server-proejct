FROM eclipse-temurin:25-jre

ENV JAVA_MIN_MEM=2G
ENV JAVA_MAX_MEM=4G

WORKDIR /app
COPY server.jar .

EXPOSE 25565

WORKDIR /data
RUN echo "eula=true" > eula.txt

CMD ["sh", "-c", "java -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM} -jar /app/server.jar nogui"]
