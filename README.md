gerricator
==========

Command-line tool to create or update [Phabricator](http://phabricator.org/) diff from [Gerrit](https://code.google.com/p/gerrit/) change

Requirements
------------
* git
* arc
* ruby (> 2.0)

Installation
------------

```bash
gem install gerricator
gerricator init
editor ~/.config/gerricator/config.yml
```

Examples
--------

```bash
# push patchset 1 in gerrit change 2020 to phabricator
gerricator push 2020 1  # outputs differential id, ex. 'D201'

# push patchset 3, update the same phabricator diff
gerricator push 2020 3

# push latest patchset in change 2020
gerricator push 2020

# does nothing because 2020#3 is already pushed
gerricator push 2020 3

# you can also use long change-id
gerricator push Id7c5ef224f847422350ecbdaa8da397ffd929f9a

# see debug logs
export VERBOSE=1
gerricator push 2020 2
```
