FROM alpine:3.12.0

LABEL maintainer="causalityloop (github@codeloft.tech)"

User root

RUN apk add --no-cache bash=5.0.17-r0 borgbackup=1.1.11-r2 sshfs=3.7.0-r4 tzdata=2020a-r0 jq=1.6-r1 curl=7.69.1-r0

ENV LANG en_US.UTF-8

WORKDIR /root/

COPY borg-backup.sh ./

CMD [ "./borg-backup.sh" ]
