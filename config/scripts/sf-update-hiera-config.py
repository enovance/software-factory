#!/usr/bin/python
# Update hiera configuration with new defaults

from sys import argv
import string
import yaml
import os

DEFAULT_ARCH = "/usr/local/share/sf-default-config/arch.yaml"


def save(name, data):
    filename = "%s/%s.yaml" % (hiera_dir, name)
    if os.path.isfile(filename):
        os.rename(filename, "%s.orig" % filename)
    yaml.dump(data, open(filename, "w"), default_flow_style=False)
    print "Updated %s (old version saved to %s)" % (filename,
                                                    "%s.orig" % filename)


def load(name):
    filename = "%s/%s.yaml" % (hiera_dir, name)
    return yaml.load(open(filename).read())


def update_sfconfig(data):
    dirty = False
    # 2.2.3: remove service list (useless since arch.yaml)
    if 'services' in data:
        del data['services']
        dirty = True

    # Make sure mirrors is in the conf
    if 'mirrors' not in data:
        data['mirrors'] = {
            'swift_mirror_url': 'http://swift:8080/v1/AUTH_uuid/repomirror/',
            'swift_mirror_tempurl_key': 'CHANGEME',
        }
        dirty = True

    # 2.2.4: refactor OAuth2 and OpenID auth config
    if 'oauth2' not in data['authentication']:
        data['authentication']['oauth2'] = {
            'github': {
                'disabled': False,
                'client_id': '',
                'client_secret': '',
                'github_allowed_organizations': ''
            },
            'google': {
                'disabled': False,
                'client_id': '',
                'client_secret': ''
            },
            'bitbucket': {
                'disabled': True,
                'client_id': '',
                'client_secret': ''
            },
        }
        dirty = True
    if 'openid' not in data['authentication']:
        data['authentication']['openid'] = {
            'disabled': False,
            'server': 'https://login.launchpad.net/+openid',
            'login_button_text': 'Log in with the Launchpad service'
        }
        dirty = True
    if data['authentication'].get('github'):
        (data['authentication']['oauth2']
         ['github']['disabled']) = (data['authentication']['github']
                                    ['disabled'])
        (data['authentication']['oauth2']
         ['github']['client_id']) = (data['authentication']['github']
                                     ['github_app_id'])
        (data['authentication']['oauth2']
         ['github']['client_secret']) = (data['authentication']['github']
                                         ['github_app_secret'])
        (data['authentication']['oauth2']['github']
         ['github_allowed_organizations']) = (data['authentication']
                                              ['github']
                                              ['github_allowed_organizations'])
        if data['authentication']['github'].get('redirect_uri'):
            (data['authentication']['oauth2']['github']
             ['redirect_uri']) = string.replace(data['authentication']
                                                ['github']['redirect_uri'],
                                                "login/github/callback",
                                                "login/oauth2/callback")
        del data['authentication']['github']
        dirty = True
    if data['authentication'].get('launchpad'):
        (data['authentication']['openid']
         ['disabled']) = data['authentication']['launchpad']['disabled']
        if data['authentication']['launchpad'].get('redirect_uri'):
            (data['authentication']['openid']
             ['redirect_uri']) = (data['authentication']['launchpad']
                                  ['redirect_uri'])
        del data['authentication']['launchpad']
        dirty = True

    if 'gerrit_connections' not in data:
        data['gerrit_connections'] = []
        dirty = True

    if 'periodic_update' not in data['mirrors']:
        data['mirrors']['periodic_update'] = False
        dirty = True
    if 'swift_mirror_ttl' not in data['mirrors']:
        data['mirrors']['swift_mirror_ttl'] = 15811200
        dirty = True

    if 'use_letsencrypt' not in data['network']:
        data['network']['use_letsencrypt'] = False

    # Mumble is enable when the role is defined in arch
    if 'disabled' in data['mumble']:
        del data['mumble']['disabled']
        dirty = True

    # 2.2.5: finished arch aware top-menu, remove service toggle now
    for hideable in ('redmine', 'etherpad', 'paste'):
        key = 'topmenu_hide_%s' % hideable
        if key in data['theme']:
            del data['theme'][key]
            dirty = True

    # 2.2.6: enforce_ssl is enabled by default
    if 'enforce_ssl' in data['network']:
        del data['network']['enforce_ssl']
        dirty = True

    # 2.2.7: add openid_connect settings
    if 'openid_connect' not in data['authentication']:
        data['authentication']['openid_connect'] = {
            'disabled': True,
            'issuer_url': None,
            'client_secret': None,
            'client_id': None,
            'login_button_text': 'Log in with OpenID Connect'
        }
        dirty = True

    # 2.2.7: add splash_image default
    if 'splash_image_data' not in data['theme']:
        add_default_splash_image(data)
        dirty = True
    return dirty


def clean_arch(data):
    dirty = False
    # Rename auth in cauth
    for host in data['inventory']:
        if 'auth' in host['roles']:
            host['roles'].remove('auth')
            host['roles'].append('cauth')
            dirty = True
    # Remove data added *IN-PLACE* by utils_refarch
    # Those are now saved in _arch.yaml instead
    for dynamic_key in ("domain", "gateway", "gateway_ip", "install",
                        "install_ip", "ip_prefix", "roles", "hosts_file"):
        if dynamic_key in data:
            del data[dynamic_key]
            dirty = True

    # Remove deployments related information
    for deploy_key in ("cpu", "disk", "mem", "hostid", "puppet_statement",
                       "rolesname", "hostname"):
        for host in data["inventory"]:
            if deploy_key in host:
                del host[deploy_key]
                dirty = True
    return dirty


if len(argv) == 2:
    hiera_dir = argv[1]
else:
    hiera_dir = "/etc/puppet/hiera/sf"

if not os.path.isdir(hiera_dir):
    print "usage: %s hiera_dir" % argv[0]
    exit(1)

# arch.yaml
try:
    arch = load("arch")
except IOError:
    # 2.1.x -> 2.2.x: arch is missing, force update
    arch = yaml.load(open(DEFAULT_ARCH).read())
    save("arch", arch)

if clean_arch(arch):
    save("arch", arch)

# sfconfig.yaml
sfconfig = load("sfconfig")
if update_sfconfig(sfconfig):
    save("sfconfig", sfconfig)

def add_default_splash_image(d):
    d['theme']['splash_image_data'] = """iVBORw0KGgoAAAANSUhEUgAAAs8AAAHtCAY
AAADm/pMXAAAABHNCSVQICAgIfAhkiAAAAAlwSFlz
AAAN1wAADdcBQiibeAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAACAASURB
VHic7N15eBtntT/w7xmNZMnWyHb2fd+6JE3SPd1butNSaCmFsvRCgQu/Wy5wgbZxyhVt7LT00gKX
C5TtFgq93Tfovq8pXdI9tNnaLM3iJF40smVLmjm/P5yGWBp5lWVL/n6ep88D74xGx5EtHb1z3vMC
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
REREREREREREREREREREREREpaL66obKwY6BiKiYyWAHQEREvRRVo8psmpxWc6b4dCoUYwCMhWIU
gNEiOk4hEQjCUPgBBABUeF1KIa0CtQE0A2hWlUYRrYegHi4+FOgONeQD1zTWt/wgvL1wPyQR0dDE
5JmIaKiKqlnhb9nfgLsYwAIAs/b8NwNAWaHDUUiriK4X4F0X8jZcvCOGvmUnrXWIilvoeIiIBgOT
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
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI
iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIhIDfx/OnEFSOpXt44AAAAASUVORK5CYII=""""
