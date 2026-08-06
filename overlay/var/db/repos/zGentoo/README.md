# ZappeL's - Gentoo portage overlay

---

## Installation

NOTE: Managing overlays via `layman` is deprecated and superseded by `eselect repository`!

### Using repositories (eselect) - preferred method

To use this method, make sure you've emerged `app-eselect/eselect-repository` before.

To add the repo, just run:

```bash
eselect repository enable zGentoo
```

Then run `emaint sync -r zGentoo` to sync it.

### Using local overlay

Create a `/etc/portage/repos.conf/zGentoo.conf` file containing

```Bash
[zGentoo]
location = /var/db/repos/zGentoo
sync-type = git
sync-uri = https://lab.simple-co.de/zappel/zGentoo.git
priority=9999
```

Then run `emerge --sync`

### Using local overlay (github mirror)

Create a `/etc/portage/repos.conf/zGentoo.conf` file containing

```Bash
[zGentoo]
location = /var/db/repos/zGentoo
sync-type = git
sync-uri = https://github.com/aspann/zGentoo.git
priority=9999
```

Then run `emerge --sync`

## Collaboration

You can directly communicate with us using discord, just follow this invite link: [zGentoo (#zgentoo)](https://discord.gg/f8xbb6g)
