# gmat2020a_box
This repository contains the files needed to install the DigitalSats GMAT development environment in a Vagrant Virtual Machine (box).
## Purpose
The DigitalSats project provides opensource repositories for enhancements to the
NASA Generalized Mission Analysis Tool - GMAT (https://gmat.atlassian.net/wiki/spaces/GW/overview?mode=global),
using Hashicorp Vagrant (https://www.vagrantup.com/).
## Environments
Both an Ubuntu 18.04 LTS Vagrant box and a Ubuntu 20.04 LTS box are available.
The scripts in this repository use lsb_release to identify the current Ubuntu release.
Current projects include providing, Windows 10, OSx 10.15 and Docker  environments (Vagrant boxes).
## File Summary
* Several installation bash shell scripts - see this repository's Wiki at https://github.com/digitalsats/gmat2020a_box/wiki/Installation-Guide
* Vagrantfile - Vagrant file that defines a Ubuntu LTS Vagrant box, currently 20.04.
