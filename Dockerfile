FROM ubuntu:22.04

RUN apt update
RUN apt install -y netcat ssh curl

WORKDIR /app

ADD scripts/entrypoint.sh .
ADD scripts/unlock-script.sh .
ADD scripts/server.py .

ENTRYPOINT [ "/app/entrypoint.sh" ]