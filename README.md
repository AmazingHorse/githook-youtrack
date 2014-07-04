githook-youtrack
================

A Ruby git commit hook to enforce that a referenced YouTrack issue exists, and to add the contents of a commit message as a comment.

Add this script to your git server, hook for pre-recieve. Requires stash for now (should change ENV vars to something out)

This will only operate if you make commits directly to master [FIXME]
