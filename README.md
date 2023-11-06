# Puppet zip

[![License](https://img.shields.io/github/license/tenangbisa/puppet-zip.svg)](https://github.com/tenangbisa/puppet-zip/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/tenangbisa/puppet-zip.png?branch=master)](https://travis-ci.org/tenangbisa/puppet-zip)
[![Code Coverage](https://coveralls.io/repos/github/tenangbisa/puppet-zip/badge.svg?branch=master)](https://coveralls.io/github/tenangbisa/puppet-zip)
[![Puppet Forge](https://img.shields.io/puppetforge/v/puppet/zip.svg)](https://forge.puppetlabs.com/puppet/zip)
[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/puppet/zip.svg)](https://forge.puppetlabs.com/puppet/zip)
[![Puppet Forge - endorsement](https://img.shields.io/puppetforge/e/puppet/zip.svg)](https://forge.puppetlabs.com/puppet/zip)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/puppet/zip.svg)](https://forge.puppetlabs.com/puppet/zip)
[![Camptocamp compatible](https://img.shields.io/badge/camptocamp-compatible-orange.svg)](https://forge.puppet.com/camptocamp/zip)

## Table of Contents

1. [Overview](#overview)
1. [Module Description](#module-description)
1. [Setup](#setup)
1. [Usage](#usage)
   * [Example](#usage-example)
   * [Puppet URL](#puppet-url)
   * [File permission](#file-permission)
   * [Network files](#network-files)
   * [Extract customization](#extract-customization)
   * [S3 Bucket](#s3-bucket)
   * [GS Bucket](#gs-bucket)
   * [Migrating from puppet-staging](#migrating-from-puppet-staging)
1. [Reference](#reference)
1. [Development](#development)

## Overview

This module manages download, deployment, and cleanup of zip files.

## Module Description

This module uses types and providers to download and manage compress files,
with optional lifecycle functionality such as checksum, extraction, and
cleanup. The benefits over existing modules such as
[puppet-staging](https://github.com/tenangbisa/puppet-staging):

* Implemented via types and provider instead of exec resource.
* Follows 302 redirect and propagate download failure.
* Optional checksum verification of zip files.
* Automatic dependency to parent directory.
* Support Windows file extraction via 7zip or PowerShell (Zip file only).
* Able to cleanup zip files after extraction.

This module is compatible with [camptocamp/zip](https://forge.puppet.com/camptocamp/zip).
For this it provides compatibility shims.

## Setup

On Windows 7zip is required to extract all zips except zip files which will
be extracted with PowerShell if 7zip is not available (requires
`System.IO.Compression.FileSystem`/Windows 2012+). Windows clients can install
7zip via `include 'zip'`. On posix systems, curl is the default provider.
The default provider can be overwritten by configuring resource defaults in
site.pp:

```puppet
zip {
  provider => 'ruby',
}
```

Users of the module are responsible for zip package dependencies, for
alternative providers and all extraction utilities such as tar, gunzip, bunzip:

```puppet
if $facts['osfamily'] != 'windows' {
  package { 'wget':
    ensure => present,
  }

  package { 'bunzip':
    ensure => present,
  }

  zip {
    provider => 'wget',
    require  => Package['wget', 'bunzip'],
  }
}
```

## Usage

zip module dependencies are managed by the `zip` class. This is only
required on Windows. By default 7zip is installed via chocolatey, but
the MSI package can be installed instead:

```puppet
class { 'zip':
  seven_zip_name     => '7-Zip 9.20 (x64 edition)',
  seven_zip_source   => 'C:/Windows/Temp/7z920-x64.msi',
  seven_zip_provider => 'windows',
}
```

To automatically load zips as part of this class you can define the
`zips` parameter.

```puppet
class { 'zip':
  zips => { '/tmp/jta-1.1.jar' => {
                  'ensure' => 'present',
                  'source'  => 'http://central.maven.org/maven2/javax/transaction/jta/1.1/jta-1.1.jar',
                  }, }
}
```

### Usage Example

Simple example that downloads from web server:

```puppet
zip { '/tmp/vagrant.deb':
  ensure => present,
  source => 'https://releases.hashicorp.com/vagrant/2.2.3/vagrant_2.2.3_x86_64.deb',
  user   => 0,
  group  => 0,
}
```

More complex example :

```puppet
include 'zip' # NOTE: optional for posix platforms

zip { '/tmp/jta-1.1.jar':
  ensure        => present,
  extract       => true,
  extract_path  => '/tmp',
  source        => 'http://central.maven.org/maven2/javax/transaction/jta/1.1/jta-1.1.jar',
  checksum      => '2ca09f0b36ca7d71b762e14ea2ff09d5eac57558',
  checksum_type => sha1,
  creates       => '/tmp/javax',
  cleanup       => true,
}

zip { '/tmp/test100k.db':
  source   => 'ftp://ftp.otenet.gr/test100k.db',
  username => 'speedtest',
  password => 'speedtest',
}
```

If you want to extract a `.tar.gz` file:

```puppet
$install_path        = '/opt/wso2'
$package_name        = 'wso2esb'
$package_ensure      = '4.9.0'
$repository_url      = 'http://company.com/repository/wso2'
$zip_name        = "${package_name}-${package_ensure}.tgz"
$wso2_package_source = "${repository_url}/${zip_name}"

zip { $zip_name:
  path         => "/tmp/${zip_name}",
  source       => $wso2_package_source,
  extract      => true,
  extract_path => $install_path,
  creates      => "${install_path}/${package_name}-${package_ensure}",
  cleanup      => true,
  require      => File['wso2_appdir'],
}
```

### Puppet URL

Since march 2017, the zip type also supports puppet URLs. Here is an example
of how to use this:

```puppet

zip { '/home/myuser/help':
  source        => 'puppet:///modules/profile/help.tar.gz',
  extract       => true,
  extract_path  => $homedir,
  creates       => "${homedir}/help" #directory inside tgz
}
```

### File permission

When extracting files as non-root user, either ensure the target directory
exists with the appropriate permission (see [tomcat.pp](tests/tomcat.pp) for
full working example):

```puppet
$dirname = 'apache-tomcat-9.0.0.M3'
$filename = "${dirname}.zip"
$install_path = "/opt/${dirname}"

file { $install_path:
  ensure => directory,
  owner  => 'tomcat',
  group  => 'tomcat',
  mode   => '0755',
}

zip { $filename:
  path          => "/tmp/${filename}",
  source        => 'http://www-eu.apache.org/dist/tomcat/tomcat-9/v9.0.0.M3/bin/apache-tomcat-9.0.0.M3.zip',
  checksum      => 'f2aaf16f5e421b97513c502c03c117fab6569076',
  checksum_type => sha1,
  extract       => true,
  extract_path  => '/opt',
  creates       => "${install_path}/bin",
  cleanup       => true,
  user          => 'tomcat',
  group         => 'tomcat',
  require       => File[$install_path],
}
```

or use an subscribing exec to chmod the directory afterwards:

```puppet
$dirname = 'apache-tomcat-9.0.0.M3'
$filename = "${dirname}.zip"
$install_path = "/opt/${dirname}"

file { '/opt/tomcat':
  ensure => 'link',
  target => $install_path
}

zip { $filename:
  path          => "/tmp/${filename}",
  source        => "http://www-eu.apache.org/dist/tomcat/tomcat-9/v9.0.0.M3/bin/apache-tomcat-9.0.0.M3.zip",
  checksum      => 'f2aaf16f5e421b97513c502c03c117fab6569076',
  checksum_type => sha1,
  extract       => true,
  extract_path  => '/opt',
  creates       => "${install_path}/bin",
  cleanup       => true,
  require       => File[$install_path],
}

exec { 'tomcat permission':
  command   => "chown tomcat:tomcat $install_path",
  path      => $path,
  subscribe => zip[$filename],
}
```

### Network files

For large binary files that needs to be extracted locally, instead of copying
the file from the network fileshare, simply set the file path to be the same as
the source and zip will use the network file location:

```puppet
zip { '/nfs/repo/software.zip':
  source        => '/nfs/repo/software.zip'
  extract       => true,
  extract_path  => '/opt',
  checksum_type => none,   # typically unecessary
  cleanup       => false,  # keep the file on the server
}
```

### Extract Customization

The `extract_flags` or `extract_command` parameters can be used to override the
default extraction command/flag (defaults are specified in
[achive.rb](lib/puppet_x/bodeco/zip.rb)).

```puppet
# tar striping directories:
zip { '/var/lib/kafka/kafka_2.10-0.8.2.1.tgz':
  ensure          => present,
  extract         => true,
  extract_command => 'tar xfz %s --strip-components=1',
  extract_path    => '/opt/kafka_2.10-0.8.2.1',
  cleanup         => true,
  creates         => '/opt/kafka_2.10-0.8.2.1/config',
}

# zip freshen existing files (zip -of %s instead of zip -o %s):
zip { '/var/lib/example.zip':
  extract       => true,
  extract_path  => '/opt',
  extract_flags => '-of',
  cleanup       => true,
  subscribe     => ...,
}
```

### S3 bucket

S3 support is implemented via the [AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html).
On non-Windows systems, the `zip` class will install this dependency when
the `aws_cli_install` parameter is set to `true`:

```puppet
class { 'zip':
  aws_cli_install => true,
}

# See AWS cli guide for credential and configuration settings:
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
file { '/root/.aws/credentials':
  ensure => file,
  ...
}
file { '/root/.aws/config':
  ensure => file,
  ...
}

zip { '/tmp/gravatar.png':
  ensure => present,
  source => 's3://bodecoio/gravatar.png',
}
```

NOTE: Alternative s3 provider support can be implemented by overriding the
[s3_download method](lib/puppet/provider/zip/ruby.rb):

### GS bucket

GSUtil support is implemented via the [GSUtil Package](https://cloud.google.com/storage/docs/gsutil).
On non-Windows systems, the `zip` class will install this dependency when
the `gsutil_install` parameter is set to `true`:

```puppet
class { 'zip':
  gsutil_install => true,
}

# See Google Cloud SDK cli guide for credential and configuration settings:
# https://cloud.google.com/storage/docs/quickstart-gsutil

zip { '/tmp/gravatar.png':
  ensure => present,
  source => 'gs://bodecoio/gravatar.png',
}
```

### Passing headers

Sometimes headers need to be passed to source. This can be accomplished
using `headers` parameter:

```puppet
zip { '/tmp/slack-desktop-4.28.184-amd64.deb':
  ensure        => present,
  extract       => true,
  extract_path  => '/tmp',
  source        => 'https://downloads.slack-edge.com/releases/linux/4.28.184/prod/x64/slack-desktop-4.28.184-amd64.deb',
  checksum      => 'e5d63dc6bd112d40c97f210af4c5f66444d4d5e8',
  checksum_type => sha1,
  headers       => ['Authorization: OAuth ABC123']
  creates       => '/usr/local/bin/slack',
  cleanup       => true,
}
```

### Download customizations

In some cases you may need custom flags for curl/wget/s3/gsutil which can be
supplied via `download_options`. Since this parameter is provider specific,
beware of the order of defaults:

* s3:// files accepts aws cli options

  ```puppet
  zip { '/tmp/gravatar.png':
    ensure           => present,
    source           => 's3://bodecoio/gravatar.png',
    download_options => ['--region', 'eu-central-1'],
  }
  ```

* puppet `provider` override:

  ```puppet
  zip { '/tmp/jta-1.1.jar':
    ensure           => present,
    source           => 'http://central.maven.org/maven2/javax/transaction/jta/1.1/jta-1.1.jar',
    provider         => 'wget',
    download_options => '--continue',
  }
  ```

* Linux default provider is `curl`, and Windows default is `ruby` (no effect).

This option can also be applied globally to address issues for specific OS:

```puppet
if $facts['osfamily'] != 'RedHat' {
  zip {
    download_options => '--tlsv1',
  }
}
```

### Migrating from puppet-staging

It is recommended to use puppet-zip instead of puppet-staging.
Users wishing to migrate may find the following examples useful.

#### puppet-staging (without extraction)

```puppet
class { 'staging':
  path  => '/tmp/staging',
}

staging::file { 'master.zip':
  source => 'https://github.com/tenangbisa/puppet-zip/zip/master.zip',
}
```

#### puppet-zip (without extraction)

```puppet
zip { '/tmp/staging/master.zip':
  source => 'https://github.com/tenangbisa/puppet-zip/zip/master.zip',
}
```

#### puppet-staging (with zip file extraction)

```puppet
class { 'staging':
  path  => '/tmp/staging',
}

staging::file { 'master.zip':
  source  => 'https://github.com/tenangbisa/puppet-zip/zip/master.zip',
} ->
staging::extract { 'master.zip':
  target  => '/tmp/staging/master.zip',
  creates => '/tmp/staging/puppet-zip-master',
}
```

#### puppet-zip (with zip file extraction)

```puppet
zip { '/tmp/staging/master.zip':
  source       => 'https://github.com/tenangbisa/puppet-zip/zip/master.zip',
  extract      => true,
  extract_path => '/tmp/staging',
  creates      => '/tmp/staging/puppet-zip-master',
  cleanup      => false,
}
```

## Reference

### Classes

* `zip`: install 7zip package (Windows only) and aws cli or gsutil for s3/gs support.
  It also permits passing an `zips` argument to generate `zip` resources.
* `zip::staging`: install package dependencies and creates staging directory
  for backwards compatibility. Use the zip class instead if you do not need
  the staging directory.

### Define Resources

* `zip::artifactory`: zip wrapper for [JFrog Artifactory](http://www.jfrog.com/open-source/#os-arti)
  files with checksum.
* `zip::go`: zip wrapper for [GO Continuous Delivery](http://www.go.cd/)
  files with checksum.
* `zip::nexus`: zip wrapper for [Sonatype Nexus](http://www.sonatype.org/nexus/)
  files with checksum.
* `zip::download`: zip wrapper and compatibility shim for [camptocamp/zip](https://forge.puppet.com/camptocamp/zip).
  This is considered private API, as it has to change with camptocamp/zip.
  For this reason it will remain undocumented, and removed when no longer needed
  . We suggest not using it directly. Instead please consider migrating to
  zip itself where possible.

### Resources

#### zip

* `ensure`: whether zip file should be present/absent (default: present)
* `path`: namevar, zip file fully qualified file path.
* `filename`: zip file name (derived from path).
* `source`: zip file source, supports http|https|ftp|file|s3|gs uri.
* `headers`: array of headers to pass source, like an authentication token
* `username`: username to download source file.
* `password`: password to download source file.
* `allow_insecure`: Ignore HTTPS certificate errors (true|false). (default: false)
* `cookie`: zip file download cookie.
* `checksum_type`: zip file checksum type (none|md5|sha1|sha2|sha256|sha384|
  sha512). (default: none)
* `checksum`: zip file checksum (match checksum_type)
* `checksum_url`: zip file checksum source (instead of specify checksum)
* `checksum_verify`: whether checksum will be verified (true|false). (default: true)
* `extract`: whether zip will be extracted after download (true|false).
  (default: false)
* `extract_path`: target folder path to extract zip.
* `extract_command`: custom extraction command ('tar xvf example.tar.gz'), also
   support sprintf format ('tar xvf %s') which will be processed with the filename:
   sprintf('tar xvf %s', filename)
* `temp_dir`: Specify an alternative temporary directory to use for copying files,
   if unset then the operating system default will be used.
* `extract_flags`: custom extraction options, this replaces the default flags.
  A string such as 'xvf' for a tar file would replace the default xf flag. A
  hash is useful when custom flags are needed for different platforms. {'tar'
  => 'xzf', '7z' => 'x -aot'}.
* `user`: extract command user (using this option will configure the zip
  file permission to 0644 so the user can read the file).
* `group`: extract command group (using this option will configure the zip
  file permission to 0644 so the user can read the file).
* `cleanup`: whether zip file will be removed after extraction (true|false).
  (default: true)
* `creates`: if file/directory exists, will not download/extract zip. If
  `extract` and `cleanup` are both `true`, this should be set to prevent Puppet
  from re-downloading and re-extracting the zip every run.
* `proxy_server`: specify a proxy server, with port number if needed. ie:
  `https://example.com:8080`.
* `proxy_type`: proxy server type (none|http|https|ftp)

#### zip::Artifactory

* `path`: fully qualified filepath for the download the file or use
  zip_path and only supply filename. (namevar).
* `ensure`: ensure the file is present/absent.
* `url`: artifactory download url filepath. NOTE: replaces server, port,
  url_path parameters.
* `server`: artifactory server name (deprecated).
* `port`: artifactory server port (deprecated).
* `url_path`: artifactory file path
  `http:://{server}:{port}/artifactory/{url_path}` (deprecated).
* `owner`: file owner (see zip params for defaults).
* `group`: file group (see zip params for defaults).
* `mode`: file mode (see zip params for defaults).
* `zip_path`: the parent directory of local filepath.
* `extract`: whether to extract the files (true/false).
* `creates`: the file created when the zip is extracted (true/false).
* `cleanup`: remove zip file after file extraction (true/false).
* `headers`: array of headers to pass source

#### zip::Artifactory Example

* retrieve gradle without authentication

  ```puppet
  $dirname = 'gradle-1.0-milestone-4-20110723151213+0300'
  $filename = "${dirname}-bin.zip"

  zip::artifactory { $filename:
    zip_path => '/tmp',
    url          => "http://repo.jfrog.org/artifactory/distributions/org/gradle/${filename}",
    extract      => true,
    extract_path => '/opt',
    creates      => "/opt/${dirname}",
    cleanup      => true,
  }

  file { '/opt/gradle':
    ensure => link,
    target => "/opt/${dirname}",
  }
  ```

* retrieve gradle with api token:

  ```puppet
  $dirname = 'gradle-1.0-milestone-4-20110723151213+0300'
  $filename = "${dirname}-bin.zip"

  zip::artifactory { $filename:
    zip_path => '/tmp',
    url          => "http://repo.jfrog.org/artifactory/distributions/org/gradle/${filename}",
    headers      => ['X-JFrog-Art-Api: ABC123'],
    extract      => true,
    extract_path => '/opt',
    creates      => "/opt/${dirname}",
    cleanup      => true,
  }

  file { '/opt/gradle':
    ensure => link,
    target => "/opt/${dirname}",
  }
  ```

* setup resource defaults

  ```puppet
  $artifactory_authentication = lookup('jfrog_token')

  zip::Artifactory {
    headers => ["X-JFrog-Art-Api: ${artifactory_authentication}"],
  }
  ```

#### zip::Nexus

#### zip::Nexus Example

```puppet
zip::nexus { '/tmp/jtstand-ui-0.98.jar':
  url        => 'https://oss.sonatype.org',
  gav        => 'org.codehaus.jtstand:jtstand-ui:0.98',
  repository => 'codehaus-releases',
  packaging  => 'jar',
  extract    => false,
}
```

## Development

We highly welcome new contributions to this module, especially those that
include documentation, and rspec tests ;) but will happily guide you through
the process, so, yes, please submit that pull request!

Note: If you are writing a dependent module that include specs in it, you will
need to set the puppetversion fact in your puppet-rspec tests. You can do that
by adding it to the default facts of your spec/spec_helper.rb:

```ruby
RSpec.configure do |c|
  c.default_facts = { :puppetversion => Puppet.version }
end
```
