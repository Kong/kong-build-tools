if ! [ -x "$(command -v systemctl)" ]; then
	# if systemd is not used, clean up the service file and its directories
	rm /lib/systemd/system/kong.service
	rmdir -p /lib/systemd/system/ > /dev/null 2>&1 || true
fi
