#!/bin/bash

####-- (Cosmetic) Colour output --####
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal


echo -e "\n ${GREEN}[+]${RESET} Installing ${GREEN}firefox's plugins${RESET} ~ Useful addons"
#--- Configure firefox
export DISPLAY=:0.0   #[[ -z $SSH_CONNECTION ]] || export DISPLAY=:0.0
#--- Download extensions
ffpath="$(find ~/.mozilla/firefox/*.default*/ -maxdepth 0 -mindepth 0 -type d -name '*.default*' -print -quit)/extensions"
[ "${ffpath}" == "/extensions" ] && echo -e ' '${RED}'[!]'${RESET}" Couldn't find Firefox/firefox folder" 1>&2
mkdir -p "${ffpath}/"

#Wappalyzer
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3204419/wappalyzer-5.8.3-fx.xpi?src=dp-btn-primary" -o "$ffpath/wappalyzer@crunchlabz.com.xpi" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'Wappalyzer'" 1>&2
#Foxyproxy standard
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3348763/foxyproxy_standard-6.6.2-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/foxyproxy@eric.h.jung.xpi" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'FoxyProxy standard'" 1>&2
#Cookies and headers analyser
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/858683/cookies_and_http_headers_analyser-2.6-an+fx-windows.xpi?src=dp-btn-primary" -o "$ffpath/{637ac5a9-47b3-475b-b724-f455f5a56897}.xpi" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'Cookies and HTTP headers analyser'" 1>&2
#Web developer toolbar
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/773845/web_developer-2.0.1-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/{c45c406e-ab73-11d8-be73-000a95be3b12}.xpi" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'Web developer toolbar'" 1>&2
#Cookie editor
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/1132754/cookie_editor-0.1.3.1-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/{48df221a-8316-4d17-9191-7fc5ea5f14c0}.xpi" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'Cookie editor'" 1>&2
#React developer tools
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/1209034/react_developer_tools-3.6.0-fx.xpi?src=dp-btn-primary" -o "$ffpath/@react-devtools.xpi" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'React developer tools'" 1>&2

#--- Installing extensions
for FILE in $(find "${ffpath}" -maxdepth 1 -type f -name '*.xpi'); do
  d="$(basename "${FILE}" .xpi)"
  mkdir -p "${ffpath}/${d}/"
  unzip -q -o -d "${ffpath}/${d}/" "${FILE}"
  rm -f "${FILE}"
done


#--- Enable Firefox's addons/plugins/extensions
timeout 15 firefox >/dev/null 2>&1   #firefox & sleep 15s; killall -q -w firefox >/dev/null
sleep 3s
# file=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'extensions.sqlite' -print -quit)   #&& [ -e "${file}" ] && cp -n $file{,.bkup}
#
# if [ ! -e "${file}" ] || [ -z "${file}" ]; then
#   #echo -e ' '${RED}'[!]'${RESET}" Something went wrong enabling firefox's extensions via method #1. Trying method #2..." 1>&2
#   false
# else
#   echo -e " ${YELLOW}[i]${RESET} Enabled ${YELLOW}Firefox's extensions${RESET} (via method #1!)"
#   apt-get install -y -qq sqlite3 || echo -e ' '${RED}'[!] Issue with apt-get'${RESET} 1>&2
#   rm -f /tmp/firefox.sql; touch /tmp/firefox.sql
#   echo "UPDATE 'main'.'addon' SET 'active' = 1, 'userDisabled' = 0;" > /tmp/firefox.sql    # Force them all!
#   sqlite3 "${file}" < /tmp/firefox.sql
# fi

file=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'extensions.json' -print -quit)   #&& [ -e "${file}" ] && cp -n $file{,.bkup}
if [ ! -e "${file}" ] || [ -z "${file}" ]; then
	false
else
	echo -e " ${YELLOW}[i]${RESET} Enabled ${YELLOW}firefox's extensions${RESET} (via method #2!)"
	sed -i 's/"active":false,/"active":true,/g' "${file}"                # Force them all!
	sed -i 's/"userDisabled":true,/"userDisabled":false,/g' "${file}"    # Force them all!
fi

file=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'prefs.js' -print -quit)   #&& [ -e "${file}" ] && cp -n $file{,.bkup}
[ ! -z "${file}" ] && sed -i '/extensions.installCache/d' "${file}"
#timeout 5 firefox >/dev/null 2>&1   # For extensions that just work without restarting
#sleep 3s
timeout 5 firefox >/dev/null 2>&1   # ...for (most) extensions, as they need firefox to restart
sleep 5s


#Force firefox restarting
killall -q -w firefox >/dev/null
sleep 5s
firefox >/dev/null 2>&1


function random_key(){
 od -A n -t u -N 4 /dev/urandom
}


#Try to generate a random key value rather using hardcoded values
fp_key1=$(random_key | sed -e 's/^[[:space:]]*//')
fp_key2=$(random_key | sed -e 's/^[[:space:]]*//')
fp_key3=$(random_key | sed -e 's/^[[:space:]]*//')
fp_key4=$(random_key | sed -e 's/^[[:space:]]*//')

#Configure Foxyproxy
file=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'storage-sync.sqlite')
if [ -z "${file}" ]; then
  echo -e ' '${RED}'[!]'${RESET}' Something went wrong with the FoxyProxy Firefox extension (did any extensions install?). Skipping...' 1>&2
else

#Flash the db. This will delete any existing entries
#sqlite3 "$file" "DELETE FROM collection_data WHERE record_id LIKE 'key-%'"

sqlite3 "$file" "INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key1', '{\"id\":\"$fp_key1\",\"key\":\"$fp_key1\",\"data\":{\"title\":\"localhost 8080\",\"type\":1,\"color\":\"#1a14cc\",\"address\":\"127.0.0.1\",\"port\":8080,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":0},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key2', '{\"id\":\"key-$fp_key2\",\"key\":\"$fp_key2\",\"data\":{\"title\":\"localhost 8081\",\"type\":1,\"color\":\"#66cc66\",\"address\":\"127.0.0.1\",\"port\":8081,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":1},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key3', '{\"id\":\"key-$fp_key3\",\"key\":\"$fp_key3\",\"data\":{\"title\":\"localhost 8069\",\"type\":1,\"color\":\"#ccac2a\",\"address\":\"127.0.0.1\",\"port\":8069,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":2},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key4', '{\"id\":\"$fp_key4\",\"key\":\"$fp_key4\",\"data\":{\"title\":\"localhost 6969\",\"type\":1,\"color\":\"#c730cc\",\"address\":\"127.0.0.1\",\"port\":6969,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":3},\"_status\":\"created\"}');" ".exit"
fi
