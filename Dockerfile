FROM alpine:3.20

LABEL org.opencontainers.image.title="LogSentry" \
      org.opencontainers.image.description="Bash CLI for Unix log analysis, reporting and backups" \
      org.opencontainers.image.source="https://github.com/dhananjay2403/logsentry-unix-cli" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.4 .0"

# bash runs the script; tar and gzip create the backup archives.
# Alpine's awk is busybox awk, which is exactly why the analysis engine
# sticks to POSIX awk.
RUN apk add --no-cache bash tar gzip

COPY logsentry /usr/local/bin/logsentry

# Analysis reads /data/logs; reports and backups are written to mounted volumes.
ENV LOG_DIR=/data/logs \
    REPORT_DIR=/data/reports \
    BACKUP_ROOT=/data/backups

RUN chmod 755 /usr/local/bin/logsentry \
    && adduser -D -h /home/logsentry logsentry \
    && mkdir -p /data/logs /data/reports /data/backups \
    && chown -R logsentry:logsentry /data

USER logsentry
WORKDIR /data

ENTRYPOINT ["logsentry"]
