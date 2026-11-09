#!/usr/bin/env bash
# Create the DNS records at DigitalOcean that point martinman.net at GitHub Pages.
#
# Idempotent: only adds records that are missing, never deletes anything.
# Mail records (MX, SPF, DKIM, DMARC) are left untouched.
#
# Usage:
#   scripts/dns-setup.sh            # create missing records
#   scripts/dns-setup.sh --dry-run  # only print what would be created
#
# Requires: doctl (authenticated), dig.
set -euo pipefail

DOMAIN="${DOMAIN:-martinman.net}"
GH_USER="${GH_USER:-mman}"
TTL="${TTL:-3600}"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site
A_RECORDS=(185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153)
AAAA_RECORDS=(2606:50c0:8000::153 2606:50c0:8001::153 2606:50c0:8002::153 2606:50c0:8003::153)
WWW_TARGET="${GH_USER}.github.io."

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

command -v doctl >/dev/null || { echo "doctl not found" >&2; exit 1; }
doctl account get >/dev/null || { echo "doctl is not authenticated (run: doctl auth init)" >&2; exit 1; }
doctl compute domain get "$DOMAIN" >/dev/null || { echo "domain $DOMAIN not found in this DigitalOcean account" >&2; exit 1; }

# Snapshot existing records once: "ID TYPE NAME DATA"
EXISTING="$(doctl compute domain records list "$DOMAIN" --format ID,Type,Name,Data --no-header)"

# has_record TYPE NAME DATA -> 0 if an identical record exists
has_record() {
  local type="$1" name="$2" data="$3"
  awk -v t="$type" -v n="$name" -v d="$data" '$2==t && $3==n && $4==d {found=1} END {exit !found}' <<<"$EXISTING"
}

# conflicts TYPE NAME -> prints "ID DATA" for records of TYPE on NAME whose DATA is not in the expected set
conflicts() {
  local type="$1" name="$2"; shift 2
  local expected=" $* "
  awk -v t="$type" -v n="$name" '$2==t && $3==n {print $1, $4}' <<<"$EXISTING" |
    while read -r id data; do
      [[ "$expected" == *" $data "* ]] || printf '%s %s\n' "$id" "$data"
    done
}

create_record() {
  local type="$1" name="$2" data="$3"
  if has_record "$type" "$name" "$data"; then
    log "ok      $type $name -> $data (exists)"
    return
  fi
  local cmd=(doctl compute domain records create "$DOMAIN"
             --record-type "$type" --record-name "$name" --record-data "$data" --record-ttl "$TTL")
  if (( DRY_RUN )); then
    log "would   ${cmd[*]}"
  else
    log "create  $type $name -> $data"
    "${cmd[@]}" --format ID,Type,Name,Data --no-header
  fi
}

# Normalize CNAME data for comparison: doctl strips the trailing dot on list output.
www_target_cmp="${WWW_TARGET%.}"

log "== Checking for conflicting records on $DOMAIN =="
found_conflict=0
while read -r id data; do
  [[ -z "$id" ]] && continue
  found_conflict=1
  warn "A @ -> $data (id $id) is not a GitHub Pages address"
  warn "  to remove: doctl compute domain records delete $DOMAIN $id"
done < <(conflicts A @ "${A_RECORDS[@]}")
while read -r id data; do
  [[ -z "$id" ]] && continue
  found_conflict=1
  warn "AAAA @ -> $data (id $id) is not a GitHub Pages address"
  warn "  to remove: doctl compute domain records delete $DOMAIN $id"
done < <(conflicts AAAA @ "${AAAA_RECORDS[@]}")
while read -r id data; do
  [[ -z "$id" ]] && continue
  found_conflict=1
  warn "CNAME www -> $data (id $id) does not point at $WWW_TARGET"
  warn "  to remove: doctl compute domain records delete $DOMAIN $id"
done < <(conflicts CNAME www "$www_target_cmp" "$WWW_TARGET")
# A/AAAA on www would also clash with the CNAME
while read -r id type name data; do
  [[ -z "$id" ]] && continue
  found_conflict=1
  warn "$type www -> $data (id $id) will clash with the www CNAME"
  warn "  to remove: doctl compute domain records delete $DOMAIN $id"
done < <(awk '($2=="A"||$2=="AAAA") && $3=="www" {print}' <<<"$EXISTING")
(( found_conflict )) || log "none"

log
log "== Ensuring GitHub Pages records on $DOMAIN =="
for ip in "${A_RECORDS[@]}";    do create_record A    @ "$ip"; done
for ip in "${AAAA_RECORDS[@]}"; do create_record AAAA @ "$ip"; done
if has_record CNAME www "$www_target_cmp" || has_record CNAME www "$WWW_TARGET"; then
  log "ok      CNAME www -> $WWW_TARGET (exists)"
else
  create_record CNAME www "$WWW_TARGET"
fi

(( DRY_RUN )) && { log; log "dry run: nothing changed"; exit 0; }

log
log "== Current records for $DOMAIN =="
doctl compute domain records list "$DOMAIN" --format Type,Name,Data,TTL

if command -v dig >/dev/null; then
  log
  log "== Resolution via ns1.digitalocean.com (authoritative, no propagation wait) =="
  log "A    $DOMAIN:     $(dig +short @ns1.digitalocean.com "$DOMAIN" A | tr '\n' ' ')"
  log "AAAA $DOMAIN:     $(dig +short @ns1.digitalocean.com "$DOMAIN" AAAA | tr '\n' ' ')"
  log "CNAME www.$DOMAIN: $(dig +short @ns1.digitalocean.com "www.$DOMAIN" CNAME | tr '\n' ' ')"
fi

log
log "Next: in the GitHub repo, Settings -> Pages, confirm custom domain is $DOMAIN,"
log "then enable 'Enforce HTTPS' once the certificate is issued (can take up to 24h):"
log "  gh api -X PUT repos/$GH_USER/$DOMAIN/pages -F https_enforced=true"
