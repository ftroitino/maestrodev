  yumrepo { 'RepoRM_Binarios':
    descr    => 'Repo de la disciplina de RSE',
    enabled  => 1,
    gpgcheck => 0,
    baseurl  => 'http://ci-rmtest.hi.inet/RepoRM_Binarios/',
  }
  package { 'mongo-10gen':
        ensure => installed,
        require => Yumrepo["RepoRM_Binarios"],
  }
  package { 'mongo-10gen-server':
        ensure => installed,
        require => Yumrepo["RepoRM_Binarios"],
  }
  file { "/home/sysadmin/mongo":
    ensure => "directory",
    require => Package["mongo-10gen-server"],
  }
  exec {"change_mongo_path":
    command => '/bin/sed -i -e "s/var\/lib\/mongo/home\/sysadmin\/mongo/g" /etc/mongod.conf',
    require => File["/home/sysadmin/mongo"],
  }
  service { 'mongod':
    require => Exec['change_mongo_path'],
    ensure => running,
    enable => true,
  }
  #package { 'erlang':
  #      ensure => installed,
  #      require => Yumrepo["RepoRM_Binarios"],
  #}
  package { 'rabbitmq-server':
        ensure => installed,
        require => Yumrepo["RepoRM_Binarios"],
  }
  exec {"module_amqp":
    command =>"/usr/bin/sudo /usr/sbin/rabbitmq-plugins enable amqp_client",
    require => Package["rabbitmq-server"],
  }
  exec {"start_rabbit":
    command =>"/usr/bin/nohup /usr/sbin/rabbitmq-server start  > /dev/null &",
    require => Exec["module_amqp"],
  }
  yumrepo { 'Repo_PushServer':
    descr    => 'Repo del Push-Server',
    enabled  => 1,
    gpgcheck => 0,
    baseurl  => 'http://ci-owd-push/RepoRM/',
  }
  package { 'PDI-OWD-Push_Server':
        ensure => installed,
        require => Yumrepo["Repo_PushServer"],
  }
  exec {"wait":
    command =>"/bin/sleep 180",
    require => Service["mongod"],
  }
  service { 'pushserverd':
    require => [ Package['PDI-OWD-Push_Server'], Exec["wait"] ],
    ensure => running,
    #enable => true,
  }
