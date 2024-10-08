$env.EDITOR = "hx"
$env.VISUAL = "hx"

mkdir ~/.cache/starship
starship init nu | save -f ~/.cache/starship/init.nu

mkdir ~/.cache/atuin
atuin init nu | save -f ~/.cache/atuin/init.nu

mkdir ~/.cache/zoxide
zoxide init nushell | save -f ~/.cache/zoxide/init.nu

mkdir ~/.cache/mise
mise activate nu | save -f ~/.cache/mise/init.nu

$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu
