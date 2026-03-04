# rspamd-iscan

[![build](https://github.com/fho/rspamd-iscan/actions/workflows/build.yml/badge.svg)](https://github.com/fho/rspamd-iscan/actions/workflows/build.yml)
[![build-publish-docker](https://github.com/JustinGuese/rspamd-iscan/actions/workflows/build-publish-docker.yml/badge.svg)](https://github.com/JustinGuese/rspamd-iscan/actions/workflows/build-publish-docker.yml)

rspamd-iscan is a daemon that monitors IMAP mailboxes and sends new mails to
[Rspamd](https://rspamd.com) for spam analysis and training.
It decouples spam filtering from mail delivery - allowing the MDA,
Rspamd and rspamd-iscan to run on totally different hosts.
For example, you can filter mails on the IMAP server of your third-party
provider with your self-hosted Rspamd instance.
It is similar to [isbg](https://gitlab.com/isbg/isbg) but uses Rspamd instead of
SpamAssassin.

rspamd-iscan continuously monitors the IMAP `ScanMailbox` for new mails with
_IMAP IDLE_. \
When a new mail arrives, it is sent to Rspamd's HTTP interface for
scanning. The scan result is added as headers to the e-mail and the modified
mail is uploaded to either the `SpamMailbox` or the `InboxMailbox`, depending on
its classification. \
The unmodified original mail is moved from the `ScanMailbox` to the
`BackupMailbox`.

Mails in the `HamMailbox` and `UndetectedMailbox` are periodically processed and
submitted to Rspamd to be learned as ham or spam. Mails learned as ham are
moved to `InboxMailbox`, learned Spam mails are moved to `SpamMailbox`.

## Installation

### From Binaries

Download and extract the binary from a [Release](https://github.com/fho/rspamd-iscan/releases).

### From Source

`go install github.com/fho/rspamd-iscan@latest`

### From Docker

**Build the image locally:**

```bash
docker build -t rspamd-iscan .
```

**Run with a mounted config file:**

```bash
docker run -d \
  --name rspamd-iscan \
  -v /path/to/config.toml:/etc/rspamd-iscan/config.toml \
  rspamd-iscan
```

Or use the pre-built image from Docker Hub (if you have configured CI):

```bash
docker run -d \
  --name rspamd-iscan \
  -v /path/to/config.toml:/etc/rspamd-iscan/config.toml \
  your-dockerhub-username/rspamd-iscan:latest
```

**GitHub Actions (CI):** To publish images on push to `main`, configure your repository:

1. Go to **Settings → Secrets and variables → Actions**
2. Add a **variable** `DOCKERHUB_USERNAME` with your Docker Hub username
3. Add a **secret** `DOCKERHUB_TOKEN` with a Docker Hub [access token](https://hub.docker.com/settings/security) (create one under Account Settings → Security)

To use a different variable or secret name, edit `.github/workflows/build-publish-docker.yml` and replace `vars.DOCKERHUB_USERNAME` and `secrets.DOCKERHUB_TOKEN` with your chosen names.

## Configuration

### Rspamd

A Rspamd instance must have been set up and it's controller HTTP interface must
be reachable.

### IMAP Server

It is recommended to use your `INBOX` mailbox to store scanned HAM mails and
reconfigure your mail-server to store new incoming mails in another mailbox,
e.g. named `Unprocessed`. This does not require changing your mail-clients'
configuration.
If that is not possible, rspamd-iscan can monitor `INBOX` instead and move
filtered Ham mails to another mailbox (e.g. named `Scanned`).
Your mail-clients would then be configured to use `HAM` as inbox.

- Ensure that you have the following mailboxes created on your IMAP server:
  - One to store mails classified as Spam (`SpamMailbox`),
  - One to store mails classified as Spam that was not detected
    (`UndetectedMailbox`),
  - One to store mails that have been wrongly classified as Spam (`HamMailbox`),
  - One to store unprocessed new mails (`ScanMailbox`),
  - One to store scanned mails classified as HAM (`InboxMailbox`)

### rspamd-iscan

rspamd-iscan is configured via a TOML configuration file.
By default, it is read from `/etc/rspamd-iscan/config.toml`, another location
can be specified by the `--cfg-file` command line parameter.

Create a new configuration file with the following content and adapt it to your
setup:

```toml
RspamdURL           = "http://192.168.178.2:11334"
RspamdPassword      = "iwonttellyou"
ImapAddr            = "my-imap-server:993"
ImapUser            = "rickdeckard"
ImapPassword        = "zhora"
InboxMailbox        = "INBOX"
SpamMailbox         = "Spam"
HamMailbox          = "Ham"
UndetectedMailbox   = "Undetected"
BackupMailbox       = "Backup"
# TempDir stores downloaded mails and their modified variants with added spam
# headers
TempDir             = "/tmp"
# Set KeepTempFiles to false to delete temporary files after use immediately
KeepTempFiles       = true
ScanMailbox         = "Unscanned"
# Mails with a higher or equal rspamd score than SpamThreshold are moved to
# SpamMailbox, others to HamMailbox
SpamThreshold       = 10.0
# Raw incoming and outgoing IMAP data is logged with debug log level.
# The logged data can contain sensitive information, like credentials.
LogIMAPData         = false
```

### Credentials Directory

Instead of storing sensitive credentials directly in the config file, you can use
the `--credentials-directory` flag to specify a directory containing credential files.
This is compatible with [systemd credentials](https://systemd.io/CREDENTIALS/).

If the credentials directory is set, rspamd-iscan looks for files named after the
config fields: `RspamdURL`, `RspamdPassword`, `ImapUser`, `ImapPassword`. If a file
exists, its content overwrites the corresponding value from the TOML config.

The `--credentials-directory` flag defaults to the `CREDENTIALS_DIRECTORY` environment
variable if not specified.

Example directory structure:
```
/run/credentials/rspamd-iscan/
├── RspamdPassword
├── ImapUser
└── ImapPassword
```

## Running

```bash
rspamd-iscan --cfg-file /etc/rspamd-iscan/config.toml 
```

better run it via systemd though :-)

## Project Status

The application is work-in-progress, the documented functionality works and is
in use, tests are missing.

## License

[EUPL](LICENSE)
