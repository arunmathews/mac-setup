#!/bin/bash
#
# If you would like to install smartcd, run the following command and
# it will download and install itself.
#
#   % curl -L http://smartcd.org/install | bash
#
# If you don't have curl, but you do have wget, try
#
#   % wget --no-check-certificate -O - http://smartcd.org/install | bash
#
# For more details about this program, visit http://github.com/cxreg/smartcd

# Order of install options is
#  1. Git clone
#  2. Download tarball
#  3. Download individual files

baseurl="https://raw.github.com/cxreg/smartcd/master"
tarurl="https://github.com/cxreg/smartcd/tarball/master"
giturl="git@personal:cxreg/smartcd.git"

if [[ -d ~/.smartcd ]]; then
    smartcd_previously_installed=1
fi

git=$(which git)
tar=$(which tar)
gunzip=$(which gunzip)
lwp=$(which lwp-request)
curl=$(which curl)
wget=$(which wget)

if [[ -n $git && ( -z $smartcd_previously_installed || -d ~/.smartcd/.git ) ]]; then
    method="git"
elif [[ -n $tar && -n $gunzip && $(tar --version 2>&1) =~ "GNU tar" ]]; then
    # Only GNU tar has the --transform argument we depend on, due to funky
    # Github tarball formatting
    method="tar"
else
    method="by-file"
fi

if [[ $method != "git" ]]; then
    if [[ -n $curl ]]; then
        download="curl -L"
    elif [[ -n $lwp ]] && perl -MCrypt::SSLeay -MLWP::Protocol::https -e '' >/dev/null 2>&1; then
        download="lwp-request"
    elif [[ -n $wget ]]; then
        download="wget --no-check-certificate -O -"
    fi
fi

if [[ $method == "by-file" && $download == "" ]]; then
    echo "I can't find git, wget or curl on your system, sorry!  Please download"
    echo "smartcd from http://github.com/cxreg/smartcd and follow the install"
    echo "instructions included."
fi

function download_file() {
    local file="$1"

    local dir=${file%/*}
    if [[ ! -d ~/.smartcd/"$dir" ]]; then
        mkdir -p ~/.smartcd/"$dir"
    fi
    dots=$(printf "%*s" $((40 - ${#file})))
    echo -n "Downloading $file${dots// /.}"
    $download "$baseurl/$file" > ~/.smartcd/"$file" 2>/dev/null
    echo "done"
}

working_dir=$(mktemp -d /tmp/smartcd-install.XXXXXX)
builtin cd $working_dir

if [[ $method == "git" ]]; then
    # Some systems wont verify github's SSL cert, so ignore it
    export GIT_SSL_NO_VERIFY=1

    # Clone into ~/.smartcd
    if [[ -d ~/.smartcd/.git ]]; then
        ( cd ~/.smartcd && $git pull )
    else
        $git clone $giturl ~/.smartcd
    fi
elif [[ $method == "tar" ]]; then
    echo -n "Downloading smartcd tarball...."
    $download $tarurl > smartcd.tar.gz 2>/dev/null
    command mkdir -p ~/.smartcd
    command $gunzip -cd smartcd.tar.gz | ( builtin cd ~ && $tar --transform 's/^[^\/]\+/.smartcd/' -xf - )
    echo "done"
else
    for file in                            \
        lib/core/smartcd                   \
        lib/core/smartcd_edit              \
        lib/core/smartcd_config            \
        lib/core/smartcd_export            \
        lib/core/smartcd_template          \
        lib/core/smartcd_upgrade_database  \
        lib/core/varstash                  \
        lib/core/arrays                    \
        lib/core/completion                \
        helper/path/script                 \
        helper/path/meta                   \
        helper/path/completion             \
        helper/history/script              \
        helper/history/meta                \
        helper/history/completion          \
        helper/perlbrew/script             \
        helper/perlbrew/meta               \
        helper/perlbrew/completion         \
        helper/perl-locallib/script        \
        helper/perl-locallib/meta          \
        helper/perl-locallib/completion
    do
        download_file "$file"
    done
fi

echo "Installation complete"
echo -n "Configure now? [Y/n] "
builtin read setup < /dev/tty
setup=$(echo $setup | tr 'A-Z' 'a-z')
: ${setup:=y}
if [[ $setup =~ "y" ]]; then
    source ~/.smartcd/lib/core/smartcd
    smartcd config
else
    echo "Run \"smartcd config\" to configure when you are ready."
fi

builtin cd ~
rm -rf $working_dir

echo "Congratulations, you have installed smartcd!"

if [[ -z $smartcd_previously_installed ]]; then
    echo "*********************************************************************"
    echo "IMPORTANT NOTE: If you just installed smartcd for the first time and"
    echo "you haven't created a new shell, it may not be loaded yet.  Run"
    echo
    echo "    source ~/.smartcd_config"
    echo "*********************************************************************"
    echo
    echo "To get started, create a few scripts.  Its easy!  Try this:"
    echo
    echo "    echo 'echo hello there from \$PWD' | smartcd edit enter"
    echo "    echo 'echo goodbye from \$PWD' | smartcd edit leave"
    echo
    echo "Then simply leave the directory and come back.  For a more practical"
    echo "example, how about tweaking your PATH?"
    echo
    echo "    echo \"autostash PATH=\$PWD/bin:\\\$PATH\" | smartcd edit enter"
    echo
    echo "(side note: the quoting rules when editing in this fashion can be a bit"
    echo "awkward, so feel free to run \`smartcd edit\` interactively too!"
    echo
    echo "When you enter the directory, your \$PATH will be updated and when you"
    echo "leave it is restored to its previous value automagically.  How cool is"
    echo "that?  For more detail on what is possible, read the documentation in"
    echo "~/.smartcd/lib/core/smartcd or refer to the README at"
    echo "https://github.com/cxreg/smartcd"
fi
