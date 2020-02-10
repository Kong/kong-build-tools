#!/bin/sh

if test -d /etc/logrotate.d/; then
  cp /etc/kong/kong.logrotate \
     /etc/logrotate.d/kong

  chmod 644 /etc/logrotate.d/kong
fi

if ! [ -x "$(command -v systemctl)" ]; then
	# if systemd is not used, clean up the service file and its directories
	rm /lib/systemd/system/kong.service
	rmdir -p /lib/systemd/system/ > /dev/null 2>&1 || true
fi

return 0
