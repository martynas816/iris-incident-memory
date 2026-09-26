FROM intersystems/iris-community:2026.2

USER root

WORKDIR /app

COPY src /app/src
COPY web /app/web
COPY iris.script /app/iris.script
COPY entrypoint.sh /app/entrypoint.sh

RUN chown -R 51773:51773 /app \
    && chmod +x /app/entrypoint.sh

USER 51773

EXPOSE 1972 52773

ENTRYPOINT ["/tini","--","/app/entrypoint.sh"]
