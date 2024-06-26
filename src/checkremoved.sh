#!/usr/bin/env bash

# Check if all authoritative servers for a TLD have removed DS records for your
# domain, and that cached data at Google Public DNS has expired

checkremoved() {
  ZONE=$(basename "$1" .).
  if [ "$ZONE" = .. ]; then
    ZONE=.
  fi
  NAME=$(basename "$ZONE" .)
  PARENT=$(expr "$NAME" : '[^.]*.\(.*\)').
  NO_NS=true
  OPTS=(+cd +noall +answer +nocl +nottl)

  dig "${OPTS[@]}" NS "$PARENT" @publicdns.goog | {
    while read -r DOMAIN TYPE NS; do
      if [ "$DOMAIN $TYPE" != "$PARENT NS" ]; then
        continue
      fi
      NO_NS=false
      if dig +cd +norecurse DS "$ZONE" "@$NS" |
        grep -E '[[:space:]]IN[[:space:]]+DS[[:space:]]' >/dev/null; then
        echo "$NS has DS record(s) for $NAME"
      else
        echo "$NS does not have DS records for $NAME"
      fi
    done

    if "$NO_NS"; then
      echo "$PARENT is not a top-level domain or delegated zone"
    else
      OLDTTL=$(
        dig +cd +dnssec DS "$ZONE" @publicdns.goog |
          awk '/^[^;]/ && $4=="RRSIG" && $5=="DS" { print $8 }'
      )
      if [ -n "$OLDTTL" ]; then
        echo "Cached DS records for $NAME expire after $OLDTTL seconds."
      else
        echo "No cached DS records found in Google Public DNS."
      fi
    fi
  }
}

checkremoved "$1"
