zip { '/tmp/bernie_301':
  ensure   => present,
  source   => 'https://berniesanders.com/for/president',
  provider => ruby,
}

zip { '/tmp/auth':
  ensure   => present,
  source   => 'http://test.webdav.org/auth-basic/',
  username => 'user1',
  password => 'user1',
  provider => ruby,
}
