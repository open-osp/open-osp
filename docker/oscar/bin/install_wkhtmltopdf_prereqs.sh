#!/usr/bin/env sh

printf "Installing required packages for wkhtmltopdf..."

# This is a noninteractive installation
export DEBIAN_FRONTEND=noninteractive

# Installed required libraries except libjpeg62-turbo; we actually need libjpeg8 instead
apt-get -qq -y --no-install-recommends install libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base > /dev/null 2>&1

# Why is libjpeg.so.8 missing from Debian?
# https://unix.stackexchange.com/a/687650

# General instructions on how to install packages using the Debian snapshot repository (but so much more is needed for very old packages)
# https://sleeplessbeastie.eu/2017/07/17/how-to-install-packages-using-repository-snapshot/
# https://unix.stackexchange.com/questions/687633/why-is-libjpeg-so-8-missing-from-debian

# Workaround "gpg: failed to create temporary file '/root/.gnupg/..."
# https://unix.stackexchange.com/questions/101400/gpg-uses-temporary-files-instead-of-pipe
gpg -k > /dev/null 2>&1

# Workaround "The following signatures couldn't be verified because the public key is not available: NO_PUBKEY 8B48AD6246925553"
# https://www.linuxfixes.com/2022/03/solved-repository-jessie-release-is-not.html
# https://unix.stackexchange.com/questions/399027/gpg-keyserver-receive-failed-server-indicated-a-failure
# https://raspberrypi.stackexchange.com/questions/12258/where-is-the-archive-key-for-backports-debian-org
# Workaround "apt-key is deprecated"
# https://askubuntu.com/questions/1295102/how-do-i-add-repo-gpg-keys-as-apt-key-is-deprecated
# https://askubuntu.com/questions/1286545/what-commands-exactly-should-replace-the-deprecated-apt-key
wheezy_key='/usr/share/keyrings/debian-archive-wheezy-automatic.gpg'
gpg --no-default-keyring --keyring gnupg-ring:$wheezy_key --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8B48AD6246925553 > /dev/null 2>&1

# Workaround "The key(s) in the keyring /etc/apt/trusted.gpg.d/debian-archive-wheezy-automatic.gpg are ignored as the file is not readable by user '_apt' executing apt-key."
chmod +r $wheezy_key

# libjpeg8 was removed from unstable on 2017-07-03, so we'll use that as the snapshot repo to get the last available version
# https://tracker.debian.org/pkg/libjpeg8
# Workaround "E: Release file for http://snapshot.debian.org/archive/debian/20141009T042436Z/dists/unstable/InRelease is expired (invalid since 2875d 16h 5min 51s). Updates for this repository will not be applied."
# https://unix.stackexchange.com/questions/602705/debian-how-do-i-install-a-specific-old-version-of-a-package-the-following-s
echo "deb [arch=$(dpkg --print-architecture) check-valid-until=no signed-by=$wheezy_key] http://snapshot.debian.org/archive/debian/20170703T215037Z/ unstable main" | tee /etc/apt/sources.list.d/snapshot.list > /dev/null

# Pin the required packages and do not install anything else from the unstable repo
# https://unix.stackexchange.com/a/242971
# https://wiki.debian.org/AptConfiguration
# https://askubuntu.com/questions/96587/is-it-possible-to-only-allow-specific-packages-updates-from-a-ppa
# Reminder that "sid" refers the unstable repo
cat << HEREDOC > /etc/apt/preferences.d/snapshot
Package: *
Pin: release n=sid
Pin-Priority: 1

Package: libjpeg8
Pin: version 8d1-2
Pin-Priority: 999

Package: multiarch-support
Pin: version 2.24-12
Pin-Priority: 999
HEREDOC

# Workaround "The following signatures were invalid: EXPKEYSIG 8B48AD6246925553 Debian Archive Automatic Signing Key (7.0/wheezy) <ftpmaster@debian.org>"
# https://salsa.debian.org/debian/mmdebstrap/-/blob/master/gpgvnoexpkeysig
curl -fsSL https://salsa.debian.org/debian/mmdebstrap/-/raw/master/gpgvnoexpkeysig > /tmp/gpgvnoexpkeysig
chmod +x /tmp/gpgvnoexpkeysig
apt-get -qq -o Apt::Key::gpgvcommand=/tmp/gpgvnoexpkeysig update > /dev/null

# libjpeg8 requires multiarch-support
# https://packages.debian.org/buster/multiarch-support
# Latest version is 2.28-10 in buster, but we'll try to see if the automatically installed older 2.24-12 works
apt-get -qq -y --no-install-recommends install libjpeg8 multiarch-support > /dev/null 2>&1

# Cleanup
apt-get autoremove > /dev/null
rm -f /tmp/gpgvnoexpkeysig
rm -f $wheezy_key
rm -f $wheezy_key~ # gpg appears to generate a backup key of zero length for some reason
rm -f /etc/apt/sources.list.d/snapshot.list
rm -f /etc/apt/preferences.d/snapshot

echo "done"
