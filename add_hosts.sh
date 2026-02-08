#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage:
  sudo ./add_hosts.sh -hl <hosts_file> -ip <ipv4>

Description:
  Adds domains from <hosts_file> to /etc/hosts mapped to <ipv4>.
  The script is idempotent: it removes existing entries for the same domains
  and writes them into a managed block.

Example:
  sudo ./add_hosts.sh -hl scopeList -ip 10.129.31.100
USAGE
}

die() { echo "[-] $*" >&2; exit 1; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run with sudo (root permissions are required to modify /etc/hosts)."
  fi
}

validate_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local IFS=.
  read -r o1 o2 o3 o4 <<< "$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
}

HL=""
IP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -hl) HL="${2:-}"; shift 2 ;;
    -ip) IP="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (use -h for help)." ;;
  esac
done

require_root
[[ -n "$HL" ]] || die "Missing required argument: -hl <hosts_file>"
[[ -n "$IP" ]] || die "Missing required argument: -ip <ipv4>"
[[ -r "$HL" ]] || die "Cannot read hosts file: $HL"
validate_ipv4 "$IP" || die "Invalid IPv4 address: $IP"

# Read domains, trim spaces, ignore blanks/comments, deduplicate
declare -A seen=()
domains=()

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="$(printf '%s' "$raw" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^# ]] && continue

  # Soft validation: allow letters, digits, dot, dash, underscore
  [[ "$line" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid domain in list: '$line'"

  if [[ -z "${seen[$line]+x}" ]]; then
    seen["$line"]=1
    domains+=("$line")
  fi
done < "$HL"

(( ${#domains[@]} > 0 )) || die "No domains found in the hosts file."

begin_marker="### BEGIN managed-by-add_hosts.sh"
end_marker="### END managed-by-add_hosts.sh"

tmp_hosts="$(mktemp)"
tmp_domains="$(mktemp)"
trap 'rm -f "$tmp_hosts" "$tmp_domains"' EXIT

printf "%s\n" "${domains[@]}" > "$tmp_domains"

# Backup /etc/hosts
backup="/etc/hosts.bak.$(date +%Y%m%d-%H%M%S)"
cp -a /etc/hosts "$backup"

# 1) Remove the old managed block (if any)
# 2) Remove any existing lines that contain these domains (to avoid conflicts)
awk -v domfile="$tmp_domains" -v b="$begin_marker" -v e="$end_marker" '
BEGIN {
  while ((getline < domfile) > 0) dom[$1]=1
  close(domfile)
  inblock=0
}
$0 == b { inblock=1; next }
$0 == e { inblock=0; next }
inblock { next }

# Keep comments/blank lines
/^[[:space:]]*#/ || /^[[:space:]]*$/ { print; next }

{
  # If any hostname field (2..NF) matches our domains, skip the line
  for (i=2; i<=NF; i++) {
    if ($i in dom) next
  }
  print
}
' /etc/hosts > "$tmp_hosts"

# Append a new managed block
{
  echo ""
  echo "$begin_marker"
  echo "# IP: $IP"
  for d in "${domains[@]}"; do
    echo "$IP $d"
  done
  echo "$end_marker"
} >> "$tmp_hosts"

# Write back safely
install -o root -g root -m 644 "$tmp_hosts" /etc/hosts

echo "[+] Done. Added ${#domains[@]} domain(s) to /etc/hosts mapped to $IP."
echo "[+] Backup created: $backup"
