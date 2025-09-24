# What is the ols-docker-installer script?
This script automate the installation of ols-docker-env project (Vanilla WordPress dockerized) and customize the containers with the name of the new website environment that the user needs to install. This is very usefull when you have to run multiple WordPress instances in your computer.

## Requirements

[x] This is script was created and tested for Mac

[x] You need Docker Desktop install on your Mac

[x] ZSH shell terminal

[ ] It might work with bash (not tested yet)

[ ] Tested in Linux (not yet)

## Usage

You can create multiple Wordpress instances. Clone your project in you home directory.

```
$ cd ~
$ git clone https://github.com/bayardorivas/ols-docker-installer.git
$ cd ols-docker-installer
$ ./install-ols <site_name>
```

The script will print out the information you need to access your new vanilla WordPress.