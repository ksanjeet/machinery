# README for KickStart export from Machinery

This directory contains an KickStart configuration that was exported by
Machinery.

The user is expected to be familiar with using KickStart.

## Using the kickstart export

The export directory contains both the KickStart profile and additional data that
is required during installation. This directory needs to be made available to
the installer via network, e.g. by running:

  cd <path>; python -m SimpleHTTPServer

You can then point the installer to the profile by specifying the KickStart
option on the kernel command line. You also need to mention the required setting for setting up network.

For RHEL 6/7 and CentOS 6/7:

  inst.ks=http://<ip>:8000/ks.cfg 

For RHEL 5:

  ks=http://<ip>:8000/ks.cfg 

## Changing permissions of the kickstart export

By default the KickStart export is only accessible by the user. This is also the
case for all sub directories.

The installation via for example an HTTP server is only possible if all files
and sub directories are readable by the HTTP server user.
To make the export directory readable for all users run:

  chmod -R a+rX <path>

## Reference

Additional information regarding KickStart is available in the official documentation: https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html
