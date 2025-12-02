## Development

Pushed commits are pulled by hosts, who then perform SSH signature verification
via Gittuf, so commits must be SSH signed via Gittuf:

```
$ gittuf clone git@codeberg.org:tomf/fleet
$ git config --local gpg.format ssh
$ git config --local user.signingkey ~/.ssh/id_ed25519_sk.pub
$ git config --local commit.gpgSign true
```