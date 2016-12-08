#!/bin/sh
exec /srv/gerrit-dash-creator/bin/gerrit-dash-creator --template-directory /srv/gerrit-dash-creator/share/gerrit-dash-creator/templates/ "$@"
