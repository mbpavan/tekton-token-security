# Token & TLS Checker

> Enhanced Token + TLS Checker
> For Tekton CD components: operator, pipelines-as-code providers, and any net/http–based Go clients.

This script enforces several security best-practices around API tokens and TLS usage in Go code:

1. **No tokens in URL query parameters**
2. **Tokens must be set in HTTP Authorization headers**
3. **No `http://` (only HTTPS/TLS allowed)**
4. **Discovery of all `net/http` imports**
5. **Validation of `http.Client` configurations for TLS**
6. **Validation of `rest.Config` for secure usage**
7. **Webhook configuration checks for secure token handling**

---

## Quick Start

1. **Clone your repo** (or place the script in your project root):

   ```bash
   git clone https://github.com/your-org/tekton-token-security-guidelines.git
   cd tekton-token-security-guidelines
   ```

2. **Run the check**:

   ```bash
   ./token-and-tls-checker.sh
   ```

   * Exits with code `0` if all checks pass.
   * Exits non-zero if any forbidden patterns or misconfigurations are found, printing details to `stderr`/`stdout`.

---

## What It Checks

### 1. Tokens in URL Query Parameters

Scans for common token query-param patterns (e.g. `?token=`, `?access_token=`) and fails if any are found.

### 2. Tokens in Authorization Header

Ensures calls use `Authorization: Bearer <token>` instead of embedding tokens in URLs.

### 3. No `http://` Usage

Searches only `.go` files (excluding vendor, tests, generated code, etc.) for `http://` and fails if any are present outside comments.

### 4. Discovery of `net/http` Imports

Lists all Go files that import `"net/http"` for further manual review.

### 5. `http.Client` TLS Configuration

For each `http.Client{}` instantiation, checks for a `TLSClientConfig` field to ensure custom TLS settings (e.g. root CAs, cert verification) are in place.

### 6. Secure `rest.Config` Usage

Validates that:

* No hard-coded `BearerToken:` values in `rest.Config`.
* A `TLSClientConfig:` block is present.

### 7. Webhook Configurations

Scans `.yaml`, `.yml`, and `.go` for webhook definitions and fails if tokens appear in URLs or un-secured fields.

---

## Usage in Tekton Repositories

To apply this script to a specific Tekton CD repository (e.g., `tektoncd/operator`):

1. **Checkout the target repo**:

   ```bash
   git clone https://github.com/tektoncd/operator.git
   cd operator
   ```

2. **Copy the script into the repo**:

   ```bash
   cp /path/to/token-and-tls-checker.sh .
   chmod +x token-and-tls-checker.sh
   ```

3. **Run the checker**:

   ```bash
   ./token-and-tls-checker.sh
   ```

   You can integrate this into CI pipelines by adding a job that runs the script and fails on non-zero exit.

---

##  Configuration

* **Exclude directories**: `vendor`, `.git`, `docs`, `hack`, `test`, `testdata`
* **Include only**: `*.go` (and for webhook checks, `*.yml` & `*.yaml`)

If you need to adjust these, edit the `EXCLUDES` and `INCLUDES` arrays at the top of the script.

---

## Exit Codes

* `0` — All checks passed
* `1` — One or more checks failed (details printed to console)

---

