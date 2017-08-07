name 'bmcs_servers'
maintainer 'The Authors'
maintainer_email 'ed.shnekendorf@oracle.com'
license 'All Rights Reserved'
description 'Installs/Configures Oracle BMCS Server'
long_description 'Installs/Configures Oracle BMCS Servers'
version '0.2.6'
chef_version '>= 12.1' if respond_to?(:chef_version)

depends 'docker', '~> 2.0'
depends 'firewall', '~> 2.0'

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
# issues_url 'https://github.com/<insert_org_here>/bmcs_servers/issues'

# The `source_url` points to the development repository for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
# source_url 'https://github.com/<insert_org_here>/bmcs_servers'
