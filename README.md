# dev-utils (Development Tools/Utilities)
Utility Scripts for Development 

* [`deploy_sphinx_docs.sh`](https://github.com/JTarball/dev-utils/blob/master/bin/deploy_sphinx_docs.sh) - deploy sphinx html documentation to gh-pages branch (which should be viewable from github pages)
* [`go-devpi.sh`](https://github.com/JTarball/dev-utils/blob/master/bin/go_devpi.sh) - ssh into AWS host: devpi
* [`go-mattermost.sh`](https://github.com/JTarball/dev-utils/blob/master/bin/go_mattermost.sh) - ssh into AWS host: mattermost
* [`go-rancher.sh`](https://github.com/JTarball/dev-utils/blob/master/bin/go_rancher.sh) - ssh into AWS host: rancher
* [`tunnel.sh`](https://github.com/JTarball/dev-utils/blob/master/bin/tunnel.sh) - Starts and stop AWS EC2 instances (Use this before and after coding to save money! Woop!)
* [`wait-for-it.sh`](https://github.com/JTarball/dev-utils/blob/master/bin/wait-for-it.sh) - Use this script to test if a given TCP host/port are available or to wait for a host/port to be ready


# How to Use

Add the following to your bash file (could be different depending on your OS):

```
~/.bash_profile
~/.profile
```

```bash
export PATH="~/<LOCATION>/dev-utils/bin:$PATH"

export DEV_UTILS_PATH="fjshjkfhdskfkjsdb"
```

Restart bash / open a new terminal and the utility scripts should be in your path and executable 
