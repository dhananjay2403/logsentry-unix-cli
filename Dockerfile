FROM ubuntu:22.04       

WORKDIR /app

COPY . .

RUN chmod +x logsentry

ENTRYPOINT ["./logsentry"]