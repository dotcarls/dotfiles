# Portable dotfiles

This repository uses chezmoi as the state engine, Homebrew Bundle as the
machine-global dependency inventory, `rage` for opaque work-domain source
material, 1Password for work credentials, and macOS Keychain for the personal
GitHub account.

The machine model is explicit. `chezmoi init` records, once and locally:

- trust domain: `personal`, `work`, or `none`
- role: `laptop`, `desktop`, `remote`, or `container`
- capabilities: interactive shell, development, GUI, MAS, and Homebrew
- policy: externally managed/MDM, GUI ownership, work configuration, and
  runtime work-secret access

Hostname guesses are intentionally not security decisions. Remote and
container roles receive no secret access by default.

## Bootstrap

Homebrew itself is the sole bootstrap exception. This repository supports only
Homebrew's documented default prefixes:

- Apple Silicon macOS: `/opt/homebrew`
- Intel macOS: `/usr/local`
- Linux: `/home/linuxbrew/.linuxbrew`

An arbitrary per-user macOS prefix is not supported because it forfeits the
normal bottle model. On Ubuntu, install Homebrew's documented build
prerequisites first; the installer may require administrator access for those
system packages. Containers must use a non-root user. Minimal containers may
set `brewEnabled = false` and receive no managed toolchain.

From a reviewed clone:

```sh
sh bootstrap-homebrew.sh --install
# Work macOS endpoint that will decrypt work configuration:
sh bootstrap-homebrew.sh --install --work
```

The script does nothing beyond discovery unless `--install` is supplied. It
downloads and runs Homebrew's official installer, then installs `chezmoi` and
`rage` through Homebrew. The work option also installs `1password-cli` through
Homebrew on macOS.

Then initialize and apply:

```sh
chezmoi init
chezmoi diff
chezmoi apply
```

## Editing and publishing

`cme` opens the chezmoi source working tree when called without a target. The
editor's source-control view therefore shows source changes that Git has not
yet staged or committed. `cm git -- push` only publishes commits; it does not
create one.

Use `cms` for the explicit one-shot local-to-remote workflow:

```sh
cms "Describe the dotfiles change"
# Or inspect the exact pending state without changing it:
dotfiles-save --dry-run
```

The helper regenerates chezmoi configuration, applies the source, stages all
source additions/modifications/deletions, commits, pulls with rebase, applies
and verifies the post-rebase state, and pushes through the configured upstream.
It never force-pushes. `cmu` is the reverse direction: it runs `chezmoi update`
to pull and apply remote changes.

On a work endpoint, authenticate the 1Password CLI before initialization and
provide the secret-reference URI for the dedicated work `rage` identity. The
pre-read hook materializes that identity as a mode-`0600` local cache. The
private key is never placed in this repository.

## Dependencies

`~/.Brewfile` is one rendered, complete union for the selected machine. Its
work-only extension is encrypted and evaluated as part of the same Bundle so
cleanup cannot reason from an incomplete layer.

```sh
dotfiles-brew check
dotfiles-brew apply             # no general upgrade pass
dotfiles-brew upgrade           # explicit update/upgrade boundary
dotfiles-brew inventory         # Bundle plus raw app/receipt audit
dotfiles-brew inventory-bundle  # valid Brewfile snapshot only
dotfiles-brew inventory-apps    # out-of-band macOS application surface
dotfiles-brew cleanup-preview   # preview only; never removes
```

Project-specific dependencies remain in the project (`mise`, `uv`, language
manifests, or a project Brewfile). MDM-owned apps and operating-system packages
are explicit exceptions, represented by machine capability choices rather than
false Homebrew ownership.

Homebrew Bundle does not provide a lockfile, so `.Brewfile.lock.json` is not
used. `brew bundle dump` cannot discover an application that has no Homebrew
receipt, and `mas list` depends on Spotlight indexing. `dotfiles-brew
inventory` therefore combines the Bundle snapshot with raw `/Applications`,
`~/Applications`, and App Store receipt inventories. New out-of-band formulae,
casks, taps, MAS apps, VS Code extensions, and supported language-global tools
are reviewed into profile data. Cleanup remains preview-only.

The work profile obtains `conjur-cli` from the repository's `dotcarls/pinned`
tap. Its formula contains immutable release URLs and reviewed SHA-256 values;
normal Homebrew evaluation performs no release-discovery request. Updating it
means reviewing the upstream release, changing `Formula/conjur-cli.rb`, and
validating the formula before publishing. `Formula/` is tap payload and is
excluded from chezmoi's home-directory projection.

## Credentials and encryption

- Personal GitHub HTTPS authentication uses GitHub CLI's macOS keyring entry.
  No GitHub token is exported through the shell or direnv.
- Homebrew GitHub REST requests use a separate, no-scope public-read token in
  the macOS Keychain generic-password item with service
  `dotfiles-homebrew-github-api` and account `github.com-public-rest`.
  `dotfiles-brew` reads it only at a `brew` process boundary and exports it to
  that child as Homebrew's documented `HOMEBREW_GITHUB_API_TOKEN`; it is never
  written to `brew.env`, a shell startup file, or direnv. The similarly named
  `HOMEBREW_GITHUB_PACKAGES_TOKEN` is for GitHub Packages, not REST API rate
  limits; the singular `HOMEBREW_GITHUB_PACKAGE_TOKEN` is not a documented
  Homebrew variable.
- Personal Git authentication stays on HTTPS through GitHub CLI's Keychain
  credential. Commit signing migrates separately to a passphrase-protected
  local SSH signing key whose passphrase is stored by Apple's SSH integration
  in Keychain:

  ```sh
  dotfiles-personal-github-keychain prepare
  dotfiles-personal-github-keychain publish
  ```

  Publishing is deliberately separate because it adds the signing public key
  to the GitHub account.
  The old 1Password item is retained for recovery until migration is verified;
  it is no longer in the managed 1Password SSH-agent allowlist.
- Work secret values remain authoritative in 1Password and are fetched only by
  exact, allowlisted helpers. Repository copies contain encrypted routing and
  reference metadata, not duplicated credential values. Use `gh-work` for an
  explicit 1Password-backed GitHub CLI process; plain `gh` remains personal.
- Work ciphertext uses a native X25519 `rage` identity, not an SSH recipient.
  Personal, work, and future host-specific recipients must never be combined
  into one global recipient list.
- Persistent remote work access is opt-in. Prefer a host-specific identity and
  encrypt only that host's required slice. Containers get runtime-injected,
  narrowly scoped credentials and never receive a persistent domain identity.

See [docs/architecture.md](docs/architecture.md) for invariants, rotation, and
the machine matrix.

## direnv

Direnv is installed for interactive profiles and hooked at the end of zsh
startup. It is for reviewed, non-secret project activation only. Every `.envrc`
must be reviewed and allowed separately on every machine.

Do not call `op`, Keychain, or `rage` from `.envrc`; do not use `dotenv`,
`source_env`, or `source_up`. Invoke secrets only at an explicit command
boundary, such as `op run -- command`. Direnv approval is arbitrary-code
approval, not a credential sandbox.

`~/.zshenv` is intentionally secret-free and non-interactive. AWS credentials
belong to SSO/profile state or an explicit runtime wrapper, never a globally
exported startup file.

## Primary references

- [chezmoi setup](https://www.chezmoi.io/user-guide/setup/), [machine differences](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/), [scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/), and [templating](https://www.chezmoi.io/user-guide/templating/)
- [chezmoi 1Password](https://www.chezmoi.io/user-guide/password-managers/1password/), [Keychain](https://www.chezmoi.io/user-guide/password-managers/keychain-and-windows-credentials-manager/), and [rage](https://www.chezmoi.io/user-guide/encryption/rage/)
- [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile), [manpage](https://docs.brew.sh/Manpage), [tips](https://docs.brew.sh/Tips-and-Tricks), [tap trust](https://docs.brew.sh/Tap-Trust), [supply-chain security](https://docs.brew.sh/Supply-Chain-Security), and [installation prefixes](https://docs.brew.sh/Installation)
- [`rage`](https://github.com/str4d/rage) and [`direnv`](https://direnv.net/)
