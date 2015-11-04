GRAPHITE_ROOT = '/usr/share/graphite'

CONF_DIR = '/etc/graphite-web'
STORAGE_DIR = '/var/lib/graphite-web'
CONTENT_DIR = '/usr/share/graphite/webapp/content'

DASHBOARD_CONF = '/etc/graphite-web/dashboard.conf'
GRAPHTEMPLATES_CONF = '/etc/graphite-web/graphTemplates.conf'

WHISPER_DIR = '/var/lib/carbon/whisper'
RRD_DIR = '/var/lib/carbon/rrd'
DATA_DIRS = [WHISPER_DIR, RRD_DIR]  # Default: set from the above variables
LOG_DIR = '/var/log/graphite-web/'
INDEX_FILE = '/var/lib/graphite-web/index'  # Search index file

DATABASES = {
    'default': {
        'NAME': '/opt/graphite/storage/graphite.db',
        'ENGINE': 'django.db.backends.sqlite3',
        'USER': '',
        'PASSWORD': '',
        'HOST': '',
        'PORT': ''
    }
}
