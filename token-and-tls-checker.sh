#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Enhanced Token + TLS Checker
# For tektoncd/operator (net/http-based clients)
# -----------------------------

EXCLUDES=(vendor .git docs hack test testdata)
INCLUDES=(--include='*.go')
EXCLUDE_ARGS=()
for d in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=(--exclude-dir="$d")
done

# Helper: check files for patterns, excluding common ignorable content
run_check() {
  local desc=$1; local pattern=$2
  echo "$desc"
  if grep -R -I -i "${INCLUDES[@]}" "${EXCLUDE_ARGS[@]}" -n -E "$pattern" . \
     | grep -v -i 'apache' \
     | grep -v -i 'licenses/' \
     | grep -v -E '(_test\.go|^\s*//|Description:\s*\"http://)' ; then
    return 1
  fi
  echo "Passed: $desc"
  return 0
}

# 1) Forbidden: token in query parameters
if ! run_check "Checking for tokens in URL query parameters…" '\\?([A-Za-z_]*_)?(token|access_token)='; then
  echo "Forbidden: found API tokens in URL query parameters" >&2
  exit 1
fi

# 2) Required: token in Authorization header
if ! run_check "Checking for tokens set in HTTP headers…" 'Authorization:\s*Bearer\s+'; then
  echo "Warning: tokens not set in HTTP headers" >&2
  exit 1
fi

# 3) Check for http:// ignoring comments and descriptions
# --------------------------------------------
echo "Checking for non-TLS (http://) usage in production dirs..."

# Run grep to match http:// in files, excluding unwanted dirs and file types
# NOTE: code might contain http clients etc, this is just to analyze furthur
matches=$(grep -RIn --include='*.go' --exclude-dir={vendor,.git,docs,test,testdata,hack} \
  'http://' cmd/ pkg/ 2>/dev/null |
  grep -v -E '_test\.go:' |
  grep -v -E '_generated\.go:' |
  grep -v -E '^\s*//|//.*http://' |
  grep -v -E 'Description:\s*\"http://' |
  grep -v -E '\.pb\.go:' |
  grep -v -i 'apache')

if [[ -n "$matches" ]]; then
  echo "$matches"
  echo "Forbidden: found 'http://' (must use HTTPS/TLS)" >&2
  exit 1
else
  echo "Passed: only HTTPS used in production code"
fi

# 4) Discover files importing net/http
NET_HTTP_FILES=$(grep -Rl --include='*.go' --exclude-dir={vendor,.git,docs,test,testdata,hack} '"net/http"' .)
echo "Files using net/http:"
echo "$NET_HTTP_FILES"

# 5) In net/http users, check for http.Client use and TLSConfig
fail=0
echo "Validating TLS usage in http.Client configs…"
for f in $NET_HTTP_FILES; do
  grep -n 'http\.Client{' "$f" | while IFS=: read -r file lineno rest; do
    window=$(sed -n "$lineno,$((lineno+10))p" "$file")
    if echo "$window" | grep -q 'TLSClientConfig'; then
      echo "TLSClientConfig found in $file near line $lineno"
    else
      echo "Missing TLSClientConfig in http.Client in $file near line $lineno"
      fail=1
    fi
  done

done

# 6) Check if rest.Config is securely used
REST_CONFIG_FILES=$(grep -Rl --include='*.go' --exclude-dir={vendor,.git,docs,test,testdata,hack} 'rest\.Config' .)
echo "Files using rest.Config:"
echo "$REST_CONFIG_FILES"

echo "Validating secure usage of rest.Config (no hardcoded tokens)…"
for f in $REST_CONFIG_FILES; do
  if grep -q 'BearerToken\s*:' "$f"; then
    echo "Possible hardcoded BearerToken in $f"
    fail=1
  fi
  if grep -q 'TLSClientConfig\s*:' "$f"; then
    echo "TLSClientConfig present in $f"
  else
    echo "Missing TLSClientConfig in rest.Config in $f"
    fail=1
  fi

done

# 7) Webhook configurations handle tokens securely
if ! run_check "Checking webhook configurations for secure token handling in YAML and Go files…" \
  -e '(^|\s)(webhook|webhookConfig).*\n(\s+token|secretToken|authToken|authorizationToken):\s*' \
  -e 'https?:\/\/[^ ]*\?(.*token=.*)' \
  --include='*.yaml' --include='*.yml' --include='*.go'; then
  echo "Warning: Webhook configurations may not handle tokens securely" >&2
  echo "   → Ensure tokens are handled via headers or request bodies over TLS" >&2
  exit 1
fi


if [ "$fail" -eq 1 ]; then
  echo "One or more required TLS or token security patterns are missing or insecure."
  exit 1
else
  echo "All net/http clients and rest.Config blocks are securely configured."
fi

