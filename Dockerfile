FROM eclipse-temurin:25-jre

# Default heap size, overridden by docker-compose. Set here so the image
# also runs standalone via "docker run" without an .env file.
ENV JAVA_MIN_MEM=1G
ENV JAVA_MAX_MEM=2G

# Application code lives in /app and stays part of the image.
WORKDIR /app
COPY server.jar .
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

EXPOSE 25565

# World data lives in /data and is persisted through a named volume.
WORKDIR /data

ENTRYPOINT ["/app/docker-entrypoint.sh"]