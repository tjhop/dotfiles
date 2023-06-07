# Dotfiles Repo

This is where I'm storing my dotfiles. Exciting, right?

This repo is being managed via [yadm](https://github.com/TheLocehiliosan/yadm), so make sure it's [installed](https://yadm.io/docs/install).

Setup dotfiles by cloning this repo with `yadm` (boostrap files are included in this repo and will run automatically after clone):
```
yadm clone --recurse-submodules --bootstrap https://github.com/tjhop/dotfiles.git
```

### Vim

Plugins are managed as submodules.

#### Add plugin

```bash
yadm submodule add $GIT_REPO $HOME/.vim/pack/plugins/start/$REPO_NAME
```

#### Removing plugin

```bash
yadm submodule deinit -f -- $HOME/.vim/pack/plugins/start/$REPO_NAME
```

#### Updating plugins

```bash
yadm submodule update --remote --recursive
```

### Tmux

Plugins are managed as submodules.

#### Add plugin

```bash
yadm submodule add $GIT_REPO $HOME/.tmux/plugins/$REPO_NAME
```

#### Removing plugin

```bash
yadm submodule deinit -f -- $HOME/.tmux/plugins/$REPO_NAME
```

#### Updating plugins

```bash
yadm submodule update --remote --recursive
```
