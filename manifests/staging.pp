#
# @summary Backwards-compatibility class for staging module
#
# @param path
#   Absolute path of staging directory to create
# @param owner
#   Username of directory owner
# @param group
#   Group of directory owner
# @param mode
#   Mode (permissions) on staging directory
#
class zip::staging (
  String $path  = $zip::params::path,
  String $owner = $zip::params::owner,
  String $group = $zip::params::group,
  String $mode  = $zip::params::mode,
) inherits zip::params {
  include 'zip'

  if !defined(File[$path]) {
    file { $path:
      ensure => directory,
      owner  => $owner,
      group  => $group,
      mode   => $mode,
    }
  }
}
