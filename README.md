githook-youtrack
================

A Ruby git commit hook to enforce that a referenced YouTrack issue exists, and to add the contents of a commit message as a comment.

Directions
----------

1. Change your git user.name variable to match your youtrack username
2. In the ruby script, add your root (or user with permissions to edit the projects) username and password.
3. Add this script to your git server, hook for pre-recieve.

Notes
-----

Enforces #{issue}s in commit messages. eg.
"#PROJ-1 Plx show up in youtrack"

This will only operate if you make commits directly to master [FIXME]

MIT Licence.
