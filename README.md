This is a NixOS homelab. Machines are defined as NixOS configurations in `hosts/`.

## Designs

- [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) who we're defending against and how
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) principles this homelab follows

## Development

Pushed commits are pulled by hosts, who then perform SSH signature verification
via Gittuf, so commits must be SSH signed via Gittuf:

```
$ gittuf clone git@codeberg.org:tomf/fleet
$ git config --local gpg.format ssh
$ git config --local user.signingkey ~/.ssh/id_ed25519_sk.pub
$ git config --local commit.gpgSign true
```

## VM tests

To run a VM test, run:

```shell
$ nix build --print-build-logs .#checks.x86_64-linux.redbox
```

Add the `--rebuild` flag to re-run.

