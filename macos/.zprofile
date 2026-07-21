eval "$(/opt/homebrew/bin/brew shellenv)"

# Setting PATH for Python 3.14
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.14/bin:${PATH}"
export PATH

# Added by Obsidian
export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"


# Added by Antigravity CLI installer
export PATH="/Users/nikobibileishvili/.local/bin:$PATH"
