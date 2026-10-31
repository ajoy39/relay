# Run 08 setup: the `labtrial` user (macOS)

Run 08's trials run as a separate macOS user, so they can't read anything
in the owner's home folder: this repo, the stub implementation, `docs/`, the
gate. See `PREREG-run-08.md` → *Treatment*. **The owner runs everything in
this file by hand**, because it needs `sudo`. Claude only writes and checks
it.

Steps 1–4 are one-time. Step 5 checks the result; **nothing runs until every
check there passes.**

## Layout

| Path | Owner : group | Mode | Who can read it |
|---|---|---|---|
| `/Users/Shared/lab` (`LAB_ROOT`) | ajoy : labshare | 0750 | ajoy, labtrial |
| `$LAB_ROOT/app` (master app) | ajoy : labshare | group read | both (trial clones borrow its objects) |
| `$LAB_ROOT/trials/` | ajoy : labshare | 2770 (setgid), files group-writable | both (each trial written by both) |
| `$LAB_ROOT/bin/run-gate` | root : wheel | 0755 | both (a wrapper; contains no answers) |
| `$LAB_ROOT/private/` (spec, reference, harness, schedule) | ajoy : staff | 0700 | **ajoy only** |

`labshare` is a group with exactly two members, `ajoy` and `labtrial`.
`labtrial`'s primary group is its own group, **not `staff`**. `/Users/ajoy` is
mode `0750` with group `staff`, so any user in `staff` could read it.

## 1. Groups and the user

```sh
# Two groups: labtrial (primary group for the trial user) and labshare.
sudo dseditgroup -o create -r "Lab trial"   labtrial
sudo dseditgroup -o create -r "Lab shared"  labshare

# The user: standard (not admin). You'll be asked for a password; save it
# in 1Password. It's only needed to log in once for the Claude login.
sudo sysadminctl -addUser labtrial -fullName "Lab trial" -password - -home /Users/labtrial
sudo createhomedir -c -u labtrial

# Primary group: labtrial, not staff (gid 20).
sudo dscl . -create /Users/labtrial PrimaryGroupID "$(dscl . -read /Groups/labtrial PrimaryGroupID | awk '{print $2}')"
sudo dseditgroup -o edit -d labtrial -t user staff 2>/dev/null || true

# labshare members: you and labtrial.
sudo dseditgroup -o edit -a ajoy     -t user labshare
sudo dseditgroup -o edit -a labtrial -t user labshare

# Hide it from the login window.
sudo dscl . -create /Users/labtrial IsHidden 1
```

## 2. The lab directories

```sh
sudo mkdir -p /Users/Shared/lab/{app,trials,bin,private}
sudo chown -R ajoy:labshare /Users/Shared/lab
sudo chmod 0750 /Users/Shared/lab /Users/Shared/lab/app
sudo chmod 2770 /Users/Shared/lab/trials
sudo chown ajoy:staff /Users/Shared/lab/private && sudo chmod 0700 /Users/Shared/lab/private
sudo chown root:wheel /Users/Shared/lab/bin && sudo chmod 0755 /Users/Shared/lab/bin
```

Two more pieces come with the lab rebuild, not here: `new_trial.sh` will make
each trial group-writable (macOS gives new files the directory's group, but
the default umask leaves them group read-only), and the runner and wrapper run
with `umask 002`, so files either user creates stay writable by the other.

`run-gate` (the wrapper) is added to `bin/` later, with the lab rebuild. It
must be owned by root and writable only by root: anything `labtrial` can
edit and then run as `ajoy` is a way into the owner's account.

## 3. Claude for `labtrial`

`claude` lives in `/Users/ajoy/.local/bin`, which `labtrial` can't read, so
it needs its own install and its own login (same subscription).

**Not `/login`.** `sudo -iu labtrial` is a shell, not a macOS login session,
so `labtrial` has no unlocked Keychain and `/login` can't save its
credential (found 2026-10-30). Trials run the same way, so they authenticate
with a long-lived token from `claude setup-token`, passed in as
`CLAUDE_CODE_OAUTH_TOKEN` by `run-trial`.

```sh
sudo -iu labtrial                                    # a shell as labtrial
curl -fsSL https://claude.ai/install.sh | bash       # installs to ~/.local/bin
~/.local/bin/claude setup-token                      # finish in the browser; it prints a token
umask 077; mkdir -p ~/.config/relay
cat > ~/.config/relay/claude-oauth-token             # paste the token, Enter, then Ctrl-D
chmod 600 ~/.config/relay/claude-oauth-token
CLAUDE_CODE_OAUTH_TOKEN="$(cat ~/.config/relay/claude-oauth-token)" \
  ~/.local/bin/claude -p "Reply with just: ok" --model claude-haiku-5-5   # prints ok
exit
```

The token is a credential for the owner's subscription: readable only by
`labtrial`, never pasted into a Claude session or a repo. It lasts about a
year; renew it with `setup-token`.

## 4. The `sudo` rules

Create the file with `sudo visudo -f /etc/sudoers.d/relay-lab` (visudo checks
the syntax; a broken sudoers file can lock you out of `sudo`):

```
# Run 08 (relay PREREG-run-08.md). Two narrow rules, no wildcards in command paths.
# 1. ajoy starts trials as labtrial without a password, only via the runner.
ajoy     ALL=(labtrial) NOPASSWD: /Users/Shared/lab/bin/run-trial
# 2. labtrial runs the gate as ajoy, only via the wrapper (refuses arm-A trials).
labtrial ALL=(ajoy)     NOPASSWD: /Users/Shared/lab/bin/run-gate
```

Both scripts arrive with the lab rebuild, owned `root:wheel`, mode `0755`.
Until they exist, these rules do nothing.

## 5. Checks (all must pass)

```sh
id labtrial                                   # no "staff" in the groups
sudo -u labtrial ls /Users/ajoy               # Permission denied
sudo -u labtrial cat /Users/ajoy/Projects/Suprvsr/relay/README.md   # Permission denied
sudo -u labtrial ls /Users/Shared/lab/private # Permission denied
sudo -u labtrial ls /Users/Shared/lab/trials  # works (empty)
sudo -u labtrial touch /Users/Shared/lab/trials/probe && ls -l /Users/Shared/lab/trials/probe && rm /Users/Shared/lab/trials/probe
sudo -u labtrial /Users/labtrial/.local/bin/claude --version   # prints a version
sudo -u labtrial ls -l /Users/labtrial/.config/relay/claude-oauth-token   # -rw------- labtrial
ls /Users/labtrial/.config/relay/ 2>&1 | head -1       # as ajoy: Permission denied (labtrial home is private)
sudo -l -U labtrial                           # only the run-gate rule
```

Paste the output to Claude. These checks are also the first entries of run
08's instrument check (`PREREG-run-08.md`, phase 0).

# Part 2: the gate user, `labgate` (Amendment A1, 2026-10-31)

The gate runs the trial's own app, so it must not run as the owner (see
`PREREG-run-08.md`, *Amendment A1*). A third user, `labgate`, owns the gate's
area and does everything that executes or `git`-inspects a trial. It can't
read `/Users/ajoy` or the owner's private area (which keeps the stub
implementation), and `labtrial` can't read the gate's area.

| Path | Owner : group | Mode | Who can read it |
|---|---|---|---|
| `$LAB_ROOT/gate/` (spec, pristine.sqlite, Playwright, browsers, schedule, log) | ajoy : labgate | 2770 | ajoy, labgate |
| `$LAB_ROOT/private/` (reference: the stub) | ajoy : staff | 0700 | **ajoy only** |
| `$LAB_ROOT/spec`, `harness` | symlinks into `gate/` | | |

## G1. The user

```sh
sudo dseditgroup -o create -r "Lab gate" labgate
sudo sysadminctl -addUser labgate -fullName "Lab gate" -password - -home /Users/labgate
sudo createhomedir -c -u labgate
sudo dscl . -create /Users/labgate PrimaryGroupID "$(dscl . -read /Groups/labgate PrimaryGroupID | awk '{print $2}')"
sudo dseditgroup -o edit -d labgate -t user staff 2>/dev/null || true
sudo dseditgroup -o edit -a labgate -t user labshare      # reads the app, writes in trials
sudo dscl . -create /Users/labgate IsHidden 1
```

## G2. The gate's area

Claude has already built `private/spec` and `private/harness` (2026-10-31).
This moves them into a `gate/` folder the gate user can use:

```sh
cd /Users/Shared/lab
mkdir gate && mv private/spec gate/spec && mv private/harness gate/harness
mkdir -p gate/log gate/browsers gate/work
rm spec harness && ln -s gate/spec spec && ln -s gate/harness harness
sudo chgrp -R labgate gate && sudo chmod -R g+rX,g-w gate && sudo chmod 2770 gate/log gate/work
touch gate/log/gate-audit.log && chgrp labgate gate/log/gate-audit.log && chmod 664 gate/log/gate-audit.log
chflags uappnd gate/log/gate-audit.log
```

**`labgate` may write only `gate/log/` and `gate/work/`** (Amendment A4). The
gate runs each trial's own code as `labgate` (seeding, the dev server), so
anything else `labgate` can write, a trial can rewrite: the spec, Playwright,
the browser, the schedule, or `gate/` itself. The audit log is append-only
(`uappnd`, set by its owner, which `labgate` is not): the gate can add lines,
and nothing can edit or delete it without the owner clearing the flag first
(`chflags nouappnd`). To edit the schedule or the spec, work as the owner;
both stay readable by `labgate`.

## G3. Git in trial folders

Trials are cloned by the owner and then worked in by `labtrial`, so git would
refuse them as "dubious ownership". Trust the trials folder, and nothing
else, for the trial user:

```sh
sudo -u labtrial -H git config --global --add safe.directory '/Users/Shared/lab/trials/*'
```

## G4. The wrappers and the `sudo` rules

Install the three wrappers, root-owned, from this repo:

```sh
sudo install -o root -g wheel -m 0755 \
  ~/Projects/Suprvsr/relay/experiments/statamic-blueprint-revisions/lab/bin/{run-trial,run-gate,lab-git} \
  /Users/Shared/lab/bin/
```

Then **replace** `/etc/sudoers.d/relay-lab` (`sudo visudo -f
/etc/sudoers.d/relay-lab`). The old `labtrial → (ajoy)` rule must go: the
gate no longer runs as the owner.

```
# Run 08 (relay PREREG-run-08.md + Amendment A1). No wildcards in command paths.
# The owner starts trials as labtrial, only via the runner.
ajoy     ALL=(labtrial) NOPASSWD: /Users/Shared/lab/bin/run-trial
# The owner scores and exports patches as labgate, only via these two.
ajoy     ALL=(labgate)  NOPASSWD: /Users/Shared/lab/bin/run-gate, /Users/Shared/lab/bin/lab-git
# A trial reaches the gate as labgate, only via the wrapper (refuses arm A).
labtrial ALL=(labgate)  NOPASSWD: /Users/Shared/lab/bin/run-gate
```

## G5. Checks (all must pass)

```sh
id labgate                                           # no "staff"
sudo -u labgate ls /Users/ajoy                       # Permission denied
sudo -u labgate ls /Users/Shared/lab/private         # Permission denied (the stub)
sudo -u labgate ls /Users/Shared/lab/gate/spec       # works
sudo -u labtrial ls /Users/Shared/lab/gate           # Permission denied
sudo -u labtrial cat /Users/Shared/lab/spec/gate.sh  # Permission denied (through the link)
ls -l /Users/Shared/lab/bin                          # three files, root wheel, -rwxr-xr-x
sudo -l -U labtrial                                  # only (labgate) run-gate
sudo -n -u labgate /Users/Shared/lab/bin/run-gate /tmp 1234; echo "rc=$?"   # refused, rc=3
```

Paste the output to Claude.

## Undo

```sh
sudo rm -f /etc/sudoers.d/relay-lab
sudo sysadminctl -deleteUser labtrial; sudo sysadminctl -deleteUser labgate
sudo dseditgroup -o delete labtrial; sudo dseditgroup -o delete labgate; sudo dseditgroup -o delete labshare
sudo rm -rf /Users/Shared/lab
```
