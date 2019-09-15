#!/bin/bash

####-- (Cosmetic) Colour output --####
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

# Start Firefox for first time
timeout 5 firefox >/dev/null 2>&1
sleep 3s

#--- Configure firefox
echo -e "\n ${BLUE}[*]${RESET} Installing useful${BLUE}Firefox${RESET} addons"

#--- Download extensions
ffpath="$(find ~/.mozilla/firefox/*.default*/ -maxdepth 0 -mindepth 0 -type d -name '*.default*' -print -quit)/extensions"
[ "${ffpath}" == "/extensions" ] && echo -e  "${RED}[!]${RESET} Couldn't find Firefox's config folder" 1>&2
mkdir -p "${ffpath}/"

# Wappalyzer
echo -e " ${YELLOW}[i]${RESET} Downloading {YELLOW}{BOLD}Wappalyzer${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3204419/wappalyzer-5.8.3-fx.xpi?src=dp-btn-primary" -o "$ffpath/wappalyzer@crunchlabz.com.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Wappalyzer${RESET}" 1>&2
# Foxyproxy standard
echo -e " ${YELLOW}[i]${RESET} Downloading {YELLOW}{BOLD}FoxyProxy standard${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3348763/foxyproxy_standard-6.6.2-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/foxyproxy@eric.h.jung.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}FoxyProxy standard${RESET}" 1>&2
# Cookies and headers analyser
echo -e " ${YELLOW}[i]${RESET} Downloading {YELLOW}{BOLD}Cookies and headers analyser${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/858683/cookies_and_http_headers_analyser-2.6-an+fx-windows.xpi?src=dp-btn-primary" -o "$ffpath/{637ac5a9-47b3-475b-b724-f455f5a56897}.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Cookies and HTTP headers analyser${RESET}" 1>&2
# Web developer toolbar
echo -e " ${YELLOW}[i]${RESET} Downloading {YELLOW}{BOLD}Web developer toolbar${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/773845/web_developer-2.0.1-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/{c45c406e-ab73-11d8-be73-000a95be3b12}.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Web developer toolbar${RESET}" 1>&2
# Cookie editor
echo -e " ${YELLOW}[i]${RESET} Downloading {YELLOW}{BOLD}Cookie editor${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/1132754/cookie_editor-0.1.3.1-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/{48df221a-8316-4d17-9191-7fc5ea5f14c0}.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Cookie editor${RESET}" 1>&2
# React developer tools
echo -e " ${YELLOW}[i]${RESET} Downloading {YELLOW}{BOLD}React developer tools${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/1209034/react_developer_tools-3.6.0-fx.xpi?src=dp-btn-primary" -o "$ffpath/@react-devtools.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}React developer tools${RESET}" 1>&2

#--- Installing extensions
for FILE in $(find "${ffpath}" -maxdepth 1 -type f -name '*.xpi'); do
  d="$(basename "$FILE" .xpi)"
  mkdir -p "${ffpath}/${d}/"
  unzip -q -o -d "${ffpath}/${d}/" "$FILE"
  rm -f "$FILE"
done

#Generate random key to use for foxyproxy configuration
function random_key() {
 od -A n -t u -N 4 /dev/urandom
}

# Restarting Firfox
echo -e " ${YELLOW}[i]${RESET} Restarting Firefox..."
timeout 5 firefox >/dev/null 2>&1
sleep 5s

#Enable plugins
FILE=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'extensions.json' -print -quit)
  echo -e " ${RED}[!]${RESET}${BOLD} extensions.js${RESET} not found! "
else
  echo -e " ${GREEN}[+]${RESET} Enabled ${GREEN}Firefox's extensions${RESET} "
  sed -i 's/"active":false,/"active":true,/g' "$FILE"                # Force them all!
  sed -i 's/"userDisabled":true,/"userDisabled":false,/g' "$FILE"    # Force them all!
fi

# Killall firefox processes
timeout 5 killall -9 -q -w firefox-esr >/dev/null

# Enable addons. Firefox must be closed.
FILE=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'prefs.js' -print -quit)
if [ ! -e "$FILE" ] || [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}${BOLD} prefs.js${RESET} not found! "
else
  echo 'user_pref("extensions.autoDiableScopes", 14);' >> "$FILE"
fi

# Configure Foxyproxy
FILE=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'storage-sync.sqlite')
if [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}Something went wrong with the${RED}${BOLD} FoxyProxy${RESET} Firefox extension (did any extensions install?).\n Skipping..." 1>&2
else
  # Flash the db. This will delete any existing entries
  echo -e " ${YELLOW}[i]${RESET} Configuring FoxyProxy settings "

  # backup old db and clean database
  cp -n "$FILE"{,.buk} && sqlite3 "$FILE" "DELETE FROM collection_data WHERE record_id LIKE 'key-%'"

  #Try to generate a random key value rather using hardcoded values
  fp_key1=$(random_key | sed -e 's/^[[:space:]]*//')
  fp_key2=$(random_key | sed -e 's/^[[:space:]]*//')
  fp_key3=$(random_key | sed -e 's/^[[:space:]]*//')
  fp_key4=$(random_key | sed -e 's/^[[:space:]]*//')

  #Insert proxy settings to db
  sqlite3 "$FILE" "INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key1', '{\"id\":\"$fp_key1\",\"key\":\"$fp_key1\",\"data\":{\"title\":\"localhost 8080\",\"type\":1,\"color\":\"#1a14cc\",\"address\":\"127.0.0.1\",\"port\":8080,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":0},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key2', '{\"id\":\"key-$fp_key2\",\"key\":\"$fp_key2\",\"data\":{\"title\":\"localhost 8081\",\"type\":1,\"color\":\"#66cc66\",\"address\":\"127.0.0.1\",\"port\":8081,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":1},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key3', '{\"id\":\"key-$fp_key3\",\"key\":\"$fp_key3\",\"data\":{\"title\":\"localhost 8069\",\"type\":1,\"color\":\"#ccac2a\",\"address\":\"127.0.0.1\",\"port\":8069,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":2},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key4', '{\"id\":\"$fp_key4\",\"key\":\"$fp_key4\",\"data\":{\"title\":\"localhost 6969\",\"type\":1,\"color\":\"#c730cc\",\"address\":\"127.0.0.1\",\"port\":6969,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":3},\"_status\":\"created\"}');" ".exit"
fi
