#!/usr/bin/env bash
# Packages are downloaded again from Arch/Tessarchy repositories during install.
# Keep their build-time archives out of the live image to preserve the netinstall's
# small download size.
rm -f /var/cache/pacman/pkg/*.pkg.tar.*
