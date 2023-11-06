#
# @summary zip wrapper for downloading files from artifactory
#
# @param url
#   artifactory download URL
# @param headers
#   HTTP header(s) to pass to source
# @param path
#   absolute path for the download file (or use zip_path and only supply filename)
# @param ensure
#   ensure download file present/absent
# @param cleanup
#   remove zip after file extraction
# @param extract
#   whether to extract the files
# @param zip_path
#   parent directory to download zip into
# @param creates
#   the file created when the zip is extracted
# @param extract_path
#   absolute path to extract zip into
# @param group
#   file group (see zip params for defaults)
# @param mode
#   file mode (see zip params for defaults)
# @param owner
#   file owner (see zip params for defaults)
# @param password
#   Password to authenticate with
# @param username
#   User to authenticate as
#
# @example
#   zip::artifactory { '/tmp/logo.png':
#     url   => 'https://repo.jfrog.org/artifactory/distributions/images/Artifactory_120x75.png',
#     owner => 'root',
#     group => 'root',
#     mode  => '0644',
#   }
# @example
#   $dirname = 'gradle-1.0-milestone-4-20110723151213+0300'
#   $filename = "${dirname}-bin.zip"
#
#   zip::artifactory { $filename:
#     zip_path => '/tmp',
#     url          => "http://repo.jfrog.org/artifactory/distributions/org/gradle/${filename}",
#     extract      => true,
#     extract_path => '/opt',
#     creates      => "/opt/${dirname}",
#     cleanup      => true,
#   }
#
define zip::artifactory (
  Stdlib::HTTPUrl $url,
  Array $headers = [],
  Boolean $cleanup = false,
  Boolean $extract = false,
  Enum['present', 'absent'] $ensure = 'present',
  String $path = $name,
  Optional[Stdlib::Absolutepath] $zip_path = undef,
  Optional[String] $creates      = undef,
  Optional[String] $extract_path = undef,
  Optional[String] $group = undef,
  Optional[String] $mode = undef,
  Optional[String] $owner = undef,
  Optional[String] $password = undef,
  Optional[String] $username = undef,
) {
  include zip::params

  if $zip_path {
    $file_path = "${zip_path}/${name}"
  } else {
    $file_path = $path
  }

  assert_type(Stdlib::Absolutepath, $file_path) |$expected, $actual| {
    fail("zip::artifactory[${name}]: \$name or \$zip_path must be '${expected}', not '${actual}'")
  }

  $maven2_data = zip::parse_artifactory_url($url)
  if $maven2_data and $maven2_data['folder_iteg_rev'] == 'SNAPSHOT' {
    # URL represents a SNAPSHOT version. eg 'http://artifactory.example.com/artifactory/repo/com/example/artifact/0.0.1-SNAPSHOT/artifact-0.0.1-SNAPSHOT.zip'
    # Only Artifactory Pro downloads this directly but the corresponding file endpoint (where the sha1 checksum is published) doesn't exist
    # This means we can't use the artifactory_sha1 function

    $latest_url_data = zip::artifactory_latest_url($url, $maven2_data)

    $file_url = $latest_url_data['url']
    $sha1     = $latest_url_data['sha1']
  } else {
    $file_url = $url
    $sha1     = zip::artifactory_checksum($url,'sha1')
  }

  zip { $file_path:
    ensure        => $ensure,
    path          => $file_path,
    extract       => $extract,
    extract_path  => $extract_path,
    headers       => $headers,
    username      => $username,
    password      => $password,
    source        => $file_url,
    checksum      => $sha1,
    checksum_type => 'sha1',
    creates       => $creates,
    cleanup       => $cleanup,
  }

  $file_owner = pick($owner, $zip::params::owner)
  $file_group = pick($group, $zip::params::group)
  $file_mode  = pick($mode, $zip::params::mode)

  file { $file_path:
    owner   => $file_owner,
    group   => $file_group,
    mode    => $file_mode,
    require => zip[$file_path],
  }
}
