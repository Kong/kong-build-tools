#!/bin/sh

samba-tool domain provision --server-role=dc --use-rfc2307 --dns-backend=SAMBA_INTERNAL --realm=ldap.mashape.com --domain=ldap --adminpass=Passw0rd && \
cat /src/smb.conf > /etc/samba/smb.conf && \
./src/add-seed-data.sh && \
samba && \
tail -f /dev/null
