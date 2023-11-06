include zip

zip { '/tmp/test.zip':
  source => 'file:///vagrant/files/test.zip',
}

zip { '/tmp/test2.zip':
  source => '/vagrant/files/test.zip',
}

# NOTE: expected to fail
zip { '/tmp/test3.zip':
  source => '/vagrant/files/invalid.zip',
}
