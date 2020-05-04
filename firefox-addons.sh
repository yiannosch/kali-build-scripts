#!/bin/bash

####-- (Cosmetic) Colour output --####
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

###--- Configure firefox ---###
# Start Firefox for first time, background process
DISPLAY=:0.0 firefox-esr &
sleep 3s                    # Add delay to make sure that the FF profile has been created

echo -e "\n ${BLUE}[*]${RESET} Installing ${BLUE}Firefox${RESET} addons"

#--- Download extensions
ffpath="$(find ~/.mozilla/firefox/*.default-esr/ -maxdepth 0 -mindepth 0 -type d -name '*.default-esr' -print -quit)/extensions"
[ "${ffpath}" == "/extensions" ] && echo -e  "${RED}[!]${RESET} Couldn't find Firefox's config folder" 1>&2
mkdir -p "${ffpath}/"

# Addons list
addon_name=("wappalyzer" "foxyproxy-standard" "cookies-and-headers-analyser" "web-developer" "cookie-quick-manager" "react-devtools" "retire-js")
addon_file=("wappalyzer@crunchlabz.com.xpi" "foxyproxy@eric.h.jung.xpi" "{637ac5a9-47b3-475b-b724-f455f5a56897}.xpi" "{c45c406e-ab73-11d8-be73-000a95be3b12}.xpi" "{60f82f00-9ad5-4de5-b31c-b16a47c51558}.xpi" "@react-devtools.xpi" "@retire.js.xpi")

for i in ${!addon_name[@]};
do
  # Get latest addon version
  ff=$(curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0" --silent "https://addons.mozilla.org/en-GB/firefox/addon/${addon_name[$i]}/" | grep -Eoi "<a [^>]+>" | grep -Eo "href=\"[^\"]+\"" | grep -Eo "(https)://addons.*xpi")

  echo -e " ${YELLOW}[i]${RESET} Downloading ${YELLOW}${BOLD}${addon_name[$i]}${RESET}"
  # Download addons inside Firefox's extensions directory
  timeout 300 curl --progress-bar -k -L -f "$ff" -o "$ffpath/${addon_file[$i]}" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}${addon_name[$i]}${RESET}" 1>&2
done

# Function to generate random keys. Used for foxyproxy configuration
function random_key() {
  rand_str="$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
  epoch="$(($(date +%s%N)/1000000))"
  echo "$rand_str$epoch"
}

# Kill firefox processes
kill -s SIGTERM $(ps -e | grep firefox-esr | awk '{print $1}')
sleep 3s

# Enable addons in extensions.js. Firefox must be closed.
FILE=$(find ~/.mozilla/firefox/*.default-esr/ -maxdepth 1 -type f -name 'extensions.json' -print -quit)
if [ ! -e "$FILE" ] || [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}${BOLD} extensions.js${RESET} not found! "
else
  echo -e "\n ${GREEN}[+]${RESET} Enabled ${GREEN}Firefox's extensions${RESET} "
  sed -i 's/"active":false,/"active":true,/g' "$FILE"
  sed -i 's/"userDisabled":true,/"userDisabled":false,/g' "$FILE"
fi

# Enable addons in pref.js. Firefox must be closed.
FILE=$(find ~/.mozilla/firefox/*.default-esr/ -maxdepth 1 -type f -name 'prefs.js' -print -quit)
if [ ! -e "$FILE" ] || [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}${BOLD} prefs.js${RESET} not found! "
else
  echo 'user_pref("extensions.autoDisableScopes", 14);' >> "$FILE"
fi

# Restarting Firfox
echo -e " ${YELLOW}[i]${RESET} Restarting Firefox..."
DISPLAY=:0.0 timeout 8 firefox >/dev/null 2>&1
sleep 3s

# Configure Foxyproxy. Firefox must be closed.
FILE=$(find ~/.mozilla/firefox/*.default-esr/ -maxdepth 1 -type f -name 'storage-sync.sqlite')
if [ ! -e "$FILE" ] || [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}Something went wrong with the${RED}${BOLD} FoxyProxy${RESET} Firefox extension (did any extensions install?).\n Skipping..." 1>&2
else
  # Flash the db. This will delete any existing entries
  echo -e " ${YELLOW}[i]${RESET} Configuring FoxyProxy settings "

  # Backup old db and clean database
  cp -n "$FILE"{,.buk} && sqlite3 "$FILE" "DELETE FROM collection_data WHERE record_id LIKE 'key-%'"

  # Generate a random key value for each entry
  fp_key1=$(random_key)
  fp_key2=$(random_key)
  fp_key3=$(random_key)
  fp_key4=$(random_key)

  # #Insert proxy settings to sqlite db
  sqlite3 "$FILE" "INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','mode','{\"id\":\"key-mode\",\"key\":\"mode\",\"data\":\"disabled\",\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key1', '{\"id\":\"key-$fp_key1\",\"key\":\"$fp_key1\",\"data\":{\"title\":\"localhost 8080\",\"type\":1,\"color\":\"#1a14cc\",\"address\":\"127.0.0.1\",\"port\":8080,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}], \"blackPatterns\":[],\"pacURL\":\"\",\"index\":0},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key2', '{\"id\":\"key-$fp_key2\",\"key\":\"$fp_key2\",\"data\":{\"title\":\"localhost 8081\",\"type\":1,\"color\":\"#66cc66\",\"address\":\"127.0.0.1\",\"port\":8081,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[],\"pacURL\":\"\",\"index\":1},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key3', '{\"id\":\"key-$fp_key3\",\"key\":\"$fp_key3\",\"data\":{\"title\":\"localhost 8069\",\"type\":1,\"color\":\"#ccac2a\",\"address\":\"127.0.0.1\",\"port\":8069,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[],\"pacURL\":\"\",\"index\":2},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key4', '{\"id\":\"key-$fp_key4\",\"key\":\"$fp_key4\",\"data\":{\"title\":\"localhost 6969\",\"type\":1,\"color\":\"#c730cc\",\"address\":\"127.0.0.1\",\"port\":6969,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[],\"pacURL\":\"\",\"index\":3},\"_status\":\"created\"}');" ".exit"
fi