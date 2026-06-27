#!/usr/bin/env python3
"""Interactive dotfiles installer."""

import subprocess
import sys
import os
import shutil
from datetime import datetime
from pathlib import Path

# ── bootstrap questionary ──────────────────────────────────────────────────────

def _ensure_questionary():
    try:
        import questionary  # noqa: F401
        return
    except ImportError:
        pass
    print("Installing questionary...")
    for extra in [["--user"], ["--break-system-packages"], []]:
        try:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", "--quiet", *extra, "questionary"],
                stderr=subprocess.DEVNULL,
            )
            return
        except subprocess.CalledProcessError:
            continue
    sys.exit("Could not install questionary. Run: pip install --user questionary")

_ensure_questionary()
import questionary
from questionary import Style

STYLE = Style([
    ("qmark",     "fg:#7dc4e4 bold"),
    ("question",  "bold"),
    ("answer",    "fg:#a6da95 bold"),
    ("pointer",   "fg:#f5a97f bold"),
    ("highlighted","fg:#f5a97f bold"),
    ("selected",  "fg:#a6da95"),
    ("separator", "fg:#6e738d"),
    ("instruction","fg:#6e738d"),
])

# ── constants ──────────────────────────────────────────────────────────────────

DOTFILES_DIR = Path(os.environ.get("DOTFILES_DIR", Path.home() / ".dotfiles"))
DOTFILES_REPO = os.environ.get("DOTFILES_REPO", "git@github.com:MiroSwisher/dotfiles.git")

# ── helpers ───────────────────────────────────────────────────────────────────

def log(msg):   print(f"\033[1;32m==>\033[0m {msg}")
def warn(msg):  print(f"\033[1;33mWARN:\033[0m {msg}", file=sys.stderr)
def error(msg): print(f"\033[1;31mERROR:\033[0m {msg}", file=sys.stderr); sys.exit(1)

def run(*args, check=True, **kwargs):
    return subprocess.run(list(args), check=check, **kwargs)

def symlink(src_rel: str, dest: Path):
    src = DOTFILES_DIR / src_rel
    if not src.exists():
        warn(f"Source not found, skipping: {src}")
        return
    if dest.is_symlink() and dest.resolve() == src.resolve():
        log(f"Already linked: {dest}")
        return
    if dest.exists() or dest.is_symlink():
        backup = dest.with_suffix(f".bak.{datetime.now():%Y%m%d-%H%M%S}")
        log(f"Backing up {dest} -> {backup}")
        dest.rename(backup)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.symlink_to(src)
    log(f"Linked {dest} -> {src}")

def cmd_exists(name): return shutil.which(name) is not None

# ── stages ────────────────────────────────────────────────────────────────────

def stage_clone():
    """Clone or update the dotfiles repo."""
    script_dir = Path(__file__).parent.resolve()
    if (script_dir / "nvim").is_dir():
        global DOTFILES_DIR
        DOTFILES_DIR = script_dir
        log(f"Using existing checkout: {DOTFILES_DIR}")
        return
    if (DOTFILES_DIR / ".git").is_dir():
        log(f"Updating {DOTFILES_DIR}")
        run("git", "-C", str(DOTFILES_DIR), "pull", "--ff-only")
    else:
        log(f"Cloning {DOTFILES_REPO} -> {DOTFILES_DIR}")
        run("git", "clone", DOTFILES_REPO, str(DOTFILES_DIR))


def stage_tools(choices):
    home = Path.home()
    local_bin = home / ".local" / "bin"
    local_bin.mkdir(parents=True, exist_ok=True)

    if "Neovim" in choices:
        if cmd_exists("nvim"):
            log(f"Found nvim: {shutil.which('nvim')}")
        else:
            log("Running shell installer for Neovim...")
            run("sh", str(DOTFILES_DIR / "install.sh"))
            return  # install.sh handles everything; exit to avoid double-running

    if "LazyVim tools (ripgrep, fd, lazygit, fzf)" in choices:
        log("Installing LazyVim support tools via shell installer...")
        env = os.environ.copy()
        env["SKIP_NVIM"] = "1"
        # Delegate to the shell script's tool-install logic
        run("sh", "-c", f'DOTFILES_DIR="{DOTFILES_DIR}" sh "{DOTFILES_DIR}/install.sh"', env=env, check=False)


def stage_configs(choices):
    home = Path.home()
    mapping = {
        "Neovim (~/.config/nvim)":          ("nvim",                    home / ".config" / "nvim"),
        "Ghostty (~/.config/ghostty/config)":("ghostty/config",          home / ".config" / "ghostty" / "config"),
        "Git (~/.gitconfig)":               ("git/gitconfig",            home / ".gitconfig"),
        "Zsh (~/.zshrc)":                   ("zsh/zshrc",               home / ".zshrc"),
        "Fastfetch (~/.config/fastfetch/config.jsonc)": (
            "fastfetch/config.jsonc", home / ".config" / "fastfetch" / "config.jsonc"
        ),
    }
    for label, (src_rel, dest) in mapping.items():
        if label in choices:
            if label.startswith("Neovim"):
                # nvim is a directory symlink
                src = DOTFILES_DIR / src_rel
                if dest.is_symlink() and dest.resolve() == src.resolve():
                    log(f"Already linked: {dest}")
                    continue
                if dest.exists() or dest.is_symlink():
                    backup = dest.with_suffix(f".bak.{datetime.now():%Y%m%d-%H%M%S}")
                    log(f"Backing up {dest} -> {backup}")
                    dest.rename(backup)
                dest.symlink_to(src)
                log(f"Linked {dest} -> {src}")
            else:
                symlink(src_rel, dest)


def stage_shell(choices):
    home = Path.home()
    env_sh = DOTFILES_DIR / "shell" / "env.sh"
    aliases_sh = DOTFILES_DIR / "shell" / "aliases.sh"
    if not env_sh.exists() or not aliases_sh.exists():
        warn("shell/env.sh or shell/aliases.sh not found; skipping shell config")
        return

    block = (
        '\n# Dotfiles shell config\n'
        'if [ -f "$HOME/.dotfiles/shell/env.sh" ]; then . "$HOME/.dotfiles/shell/env.sh"; fi\n'
        'if [ -f "$HOME/.dotfiles/shell/aliases.sh" ]; then . "$HOME/.dotfiles/shell/aliases.sh"; fi\n'
    )

    rc_map = {"Bash (~/.bashrc)": home / ".bashrc", "Zsh (~/.zshrc)": home / ".zshrc"}
    for label, rc in rc_map.items():
        if label not in choices:
            continue
        if not rc.exists():
            rc.write_text("")
        content = rc.read_text()
        if "Dotfiles shell config" in content:
            log(f"Shell config already present in {rc.name}")
        else:
            rc.write_text(content + block)
            log(f"Added dotfiles shell config to {rc.name}")


def stage_nvim_plugins():
    if cmd_exists("nvim"):
        log("Syncing Neovim plugins...")
        run("nvim", "--headless", "+Lazy! sync", "+qa", check=False)
    else:
        warn("nvim not found; skipping plugin sync")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    print()
    print("\033[1;35m  dotfiles installer\033[0m")
    print()

    # Stage 1: always clone/update
    stage_clone()
    print()

    # Stage 2: tools
    tool_choices = questionary.checkbox(
        "Which tools should be installed?",
        choices=[
            "Neovim",
            "LazyVim tools (ripgrep, fd, lazygit, fzf)",
        ],
        style=STYLE,
    ).ask()
    if tool_choices is None:
        sys.exit(0)

    # Stage 3: config symlinks
    config_choices = questionary.checkbox(
        "Which configs should be symlinked into ~/?",
        choices=[
            questionary.Choice("Neovim (~/.config/nvim)",     checked=True),
            questionary.Choice("Ghostty (~/.config/ghostty/config)", checked=True),
            questionary.Choice("Git (~/.gitconfig)",           checked=True),
            questionary.Choice("Zsh (~/.zshrc)",               checked=True),
            questionary.Choice("Fastfetch (~/.config/fastfetch/config.jsonc)", checked=True),
        ],
        style=STYLE,
    ).ask()
    if config_choices is None:
        sys.exit(0)

    # Stage 4: shell injection (only if NOT symlinking .zshrc — symlinked zshrc already sources it)
    shell_prompt_choices = ["Bash (~/.bashrc)"]
    if "Zsh (~/.zshrc)" not in config_choices:
        shell_prompt_choices.append("Zsh (~/.zshrc)")

    shell_choices = questionary.checkbox(
        "Inject dotfiles shell config (env + aliases) into which rc files?",
        choices=[questionary.Choice(c, checked=True) for c in shell_prompt_choices],
        style=STYLE,
    ).ask()
    if shell_choices is None:
        sys.exit(0)

    # Stage 5: nvim plugins
    sync_plugins = questionary.confirm(
        "Sync Neovim plugins now? (requires nvim to be installed)",
        default=True,
        style=STYLE,
    ).ask()
    if sync_plugins is None:
        sys.exit(0)

    # Summary
    print()
    print("\033[1mReady to install:\033[0m")
    if tool_choices:
        for t in tool_choices:
            print(f"  • {t}")
    if config_choices:
        for c in config_choices:
            print(f"  • Symlink {c}")
    if shell_choices:
        for s in shell_choices:
            print(f"  • Inject shell config into {s}")
    if sync_plugins:
        print("  • Sync Neovim plugins")
    print()

    confirm = questionary.confirm("Proceed?", default=True, style=STYLE).ask()
    if not confirm:
        print("Aborted.")
        sys.exit(0)

    print()

    # Execute
    if tool_choices:
        stage_tools(tool_choices)
    if config_choices:
        stage_configs(config_choices)
    if shell_choices:
        stage_shell(shell_choices)
    if sync_plugins:
        stage_nvim_plugins()

    print()
    log("Done!")
    if "Zsh (~/.zshrc)" in (config_choices or []):
        print("  Machine-specific config (course paths, project aliases, etc.) goes in ~/.zshrc.local")
    print("  Restart your shell or run: exec zsh")


if __name__ == "__main__":
    main()
