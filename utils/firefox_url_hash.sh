#!/usr/bin/env bash

###################################################################################################
# A helper script to calculate the url_hash used in places.sqlite by Mozilla Firefox 50 and later.#
# This is a bash port of https://github.com/bencaradocdavies/sqlite-mozilla-url-hash and \        #
# https://gist.github.com/boppreh/a9737acb2abf015e6e828277b40efe71                                #
###################################################################################################
golden_ratio="0x9E3779B9"
max_int="$((2**32 - 1))"

rotate_left_5()
{
    var1="$(( $(($1 << 5 )) | $(($1 >> 27)) ))"
    var2="$(($var1 & $max_int))"
    echo "$var2"
}

add_to_hash()
{
    var3=$(rotate_left_5 $1)
    var4=$(($var3 ^ $2))
    var5=$(($golden_ratio * $var4))
    var6=$(($var5 & $max_int))
    echo "$var6"
}

# String to ASCII Conversion Helper function
ord()
{
  LC_NUMERIC=C printf '%d' "'$1"
}

hash_simple()
{
    hash_value=0
    while read -n1 char; do
       ord_char=$(ord $char)
       hash_value=$(add_to_hash $hash_value $ord_char)
    done < <(echo -n "$1")
    echo "$hash_value"
}

url_hash()
{
    prefix=$(echo "$1" | cut -f1 -d":")
    var6=$(hash_simple $prefix)
    var7=$(($var6 & 0x0000FFFF))
    var8=$(($var7 << 32))
    var9=$(hash_simple $1)
    var10=$(($var8 + $var9))
    echo "$var10"
}
