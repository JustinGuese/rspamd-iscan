# rspamd-iscan

[![build](https://github.com/fho/rspamd-iscan/actions/workflows/build.yml/badge.svg)](https://github.com/fho/rspamd-iscan/actions/workflows/build.yml)
[![build-publish-docker](https://github.com/JustinGuese/rspamd-iscan/actions/workflows/build-publish-docker.yml/badge.svg)](https://github.com/JustinGuese/rspamd-iscan/actions/workflows/build-publish-docker.yml)

> **The main repository is at [fho/rspamd-iscan](https://github.com/fho/rspamd-iscan). This repo provides the Docker image and Helm chart.**

rspamd-iscan is a daemon that monitors IMAP mailboxes and sends new mails to [Rspamd](https://rspamd.com) for spam analysis and training. It decouples spam filtering from mail delivery — allowing the MDA, Rspamd, and rspamd-iscan to run on entirely separate hosts. For example, you can filter mails on the IMAP server of your third-party provider using your self-hosted Rspamd instance. It is similar to [isbg](https://gitlab.com/isbg/isbg) but uses Rspamd instead of SpamAssassin.

---

## Quick start (Docker)

**Build and run locally:**

```bash
docker build -t rspamd-iscan .

docker run -d \
  --name rspamd-iscan \
  -v /path/to/config.toml:/etc/rspamd-iscan/config.toml \
  rspamd-iscan
```

Or pull the pre-built image:

```bash
docker pull guestros/rspamd-iscan
```

---

## Helm (Kubernetes)

The Helm chart deploys the full stack: Rspamd + rspamd-iscan, with an optional in-cluster Redis.

### Install from GHCR

No `helm repo add` needed — install directly via OCI:

```bash
helm install rspamd-iscan oci://ghcr.io/justinguese/rspamd-iscan \
  --set rspamdIscan.imapAddr="imap.example.com:993" \
  --set rspamdIscan.imapUser="you@example.com"
```

Or clone and install locally from `helm/rspamd-iscan/`.

### 1. Create the IMAP password secret

Only your IMAP password needs to be in a Kubernetes Secret — it is never managed by Helm and never stored in git. Your username and all other settings go in values.

```bash
kubectl create namespace spamfilter

kubectl create secret generic spamfilter-rspamd-iscan-secret \
  -n spamfilter \
  --from-literal=ImapPassword='yourpassword'
```

The Rspamd controller password is auto-generated on first `helm install` and stored in a separate secret in the cluster.

### 2. Install the chart

At minimum you must provide your IMAP server address and username:

```bash
helm install rspamd-iscan oci://ghcr.io/justinguese/rspamd-iscan \
  --set rspamdIscan.imapAddr="imap.example.com:993" \
  --set rspamdIscan.imapUser="you@example.com"
```

**With an external Redis** (disable the built-in one):

```bash
helm install rspamd-iscan oci://ghcr.io/justinguese/rspamd-iscan \
  --set rspamdIscan.imapAddr="imap.example.com:993" \
  --set rspamdIscan.imapUser="you@example.com" \
  --set redis.enabled=false \
  --set rspamd.redisServer="redis-service.redis.svc.cluster.local:6379"
```

All options are documented in `helm/rspamd-iscan/values.yaml`.

### IMAP mailbox setup

The `rspamdIscan.mailboxes` section controls which IMAP folders are used:

| Key | Purpose | Default |
|---|---|---|
| `scan` | Incoming unprocessed mail — rspamd-iscan watches this | `INBOX.Unscanned` |
| `inbox` | Clean mail is moved here after scanning | `INBOX` |
| `spam` | Detected spam is moved here | `INBOX.Junk` |
| `ham` | Drop false positives here to train Rspamd | `INBOX` |
| `undetected` | Drop missed spam here to train Rspamd | `INBOX.Undetected` |
| `backup` | Archive copy of all processed messages | `INBOX.BackupMailbox` |

> **Note:** `Undetected`, `Unscanned`, and `BackupMailbox` are non-standard folders — most providers won't create them automatically. Create them manually in your mail client or provider's webmail before deploying.

**Recommended mail provider setup:** Configure a server-side rule to deliver all incoming mail into the `scan` folder instead of `INBOX`. rspamd-iscan will then sort it automatically.

> I am using [Hostinger Email](https://www.hostinger.com?REFERRALCODE=RQHGUESEJPZB) (~€1/month) — good, cheap, and works great with this setup. If this saved you some time, feel free to use the referral link and buy me a coffee ☕

### How training works

- **Missed spam in inbox** → drag it to `undetected` — rspamd-iscan will use it as a spam training example
- **Legitimate mail in spam** → drag it to `ham` — rspamd-iscan will use it as a ham training example

---

## CI / Docker image

The GitHub Actions workflow builds and publishes a new Docker image automatically:

- On every push to `main` (e.g. Dockerfile changes)
- Weekly, if the upstream repo ([fho/rspamd-iscan](https://github.com/fho/rspamd-iscan)) has new commits — checked via commit SHA caching, so no unnecessary rebuilds

**To publish images from your own fork**, configure:

1. **Settings → Secrets and variables → Actions**
2. Add variable `DOCKERHUB_USERNAME` — your Docker Hub username
3. Add secret `DOCKERHUB_TOKEN` — a Docker Hub [access token](https://hub.docker.com/settings/security)
