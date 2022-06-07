FROM nginx:1.17.3-alpine

RUN apk add --no-cache samba-dc bash ldb-tools

COPY smb.conf add-seed-data.sh /src/
COPY entrypoint.sh /

RUN rm -f /etc/samba/smb.conf

ENTRYPOINT ["/entrypoint.sh"]
