FROM ubuntu:22.04       

WORKDIR /app

COPY . .

RUN chmod +x logsentry

ENV LOG_DIR=/data/logs
ENV REPORT_DIR=/data/reports
ENV BACKUP_ROOT=/data/backups

ENTRYPOINT ["./logsentry"]