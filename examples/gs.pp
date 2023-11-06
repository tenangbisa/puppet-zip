class { 'zip':
  gsutil_install => true,
}

zip { '/tmp/gravatar.png':
  ensure => present,
  source => 'gs://bodecoio/gravatar.png',
}
