# @summary OS specific `zip` settings such as default user and file mode.
# @api private
class zip::params {
  case $facts['os']['family'] {
    'Windows': {
      $path               = $facts['zip_windir']
      $owner              = 'S-1-5-32-544' # Adminstrators
      $group              = 'S-1-5-18'     # SYSTEM
      $mode               = '0640'
      $seven_zip_name     = '7zip'
      $seven_zip_provider = 'chocolatey'
    }
    default: {
      $path  = '/opt/staging'
      $owner = '0'
      $group = '0'
      $mode  = '0640'
      $seven_zip_name = undef
      $seven_zip_provider = undef
    }
  }
}
