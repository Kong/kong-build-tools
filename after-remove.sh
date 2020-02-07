#!/bin/sh

if test -f /etc/logrotate.d/kong; then
        rm /etc/logrotate.d/kong
fi

if test -f /lib/systemd/system/kong.service; then
        rm /lib/systemd/system/kong.service
fi

return 0
