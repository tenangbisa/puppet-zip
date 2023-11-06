class { 'zip':
  aws_cli_install => true,
}

zip { '/tmp/gravatar.png':
  ensure => present,
  source => 's3://bodecoio/gravatar.png',
}
