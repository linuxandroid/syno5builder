#!/bin/sh

PATH="$PATH:/bin"
PATH="$PATH:/sbin"

echo ${HTTP_USER_AGENT} | grep -i -e iphone -e ipod > /dev/null
is_ios=$?

echo ${HTTP_USER_AGENT} |  grep -iv ipad | grep -i -e phone -e mobile -e android -e blackberry -e htc -e nokia -e sonyericsson -e operamobi -e operamini -e palm > /dev/null
is_mobile=$?

echo ${HTTP_USER_AGENT} | grep -i webkit > /dev/null
is_webkit=$?

dir=web_index.html
if [ "yes" = "$(get_key_value /etc/synoinfo.conf support_pci_wifi)" ] && \
	[ $is_webkit = "0" ] && [ $is_ios = "0" -o $is_mobile = "0" ]; then
	dir=mobile_installer/index.html
fi


cat << EOF
Expires: Mon, 26 Jul 1990 05:00:00 GMT
Cache-Control: no-store, no-cache, must-revalidate
Pragma: no-cache
Content-type: text/html

<html>
	<head>
		<title>Synology Redirect CGI</title>
		<meta http-equiv="REFRESH" content="0;url=$dir">
		<meta http-equiv="cache-control" content="no-cache">
		<meta http-equiv="pragma" content="no-cache">
		<meta http-equiv="expires" content="0">
	</head>
	<body>
	</body>
</html>

EOF
