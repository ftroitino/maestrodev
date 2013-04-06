  yumrepo { 'RepoRM_Binarios':
    descr    => 'Repo de la disciplina de RSE',
    enabled  => 1,
    gpgcheck => 0,
    #baseurl  => 'http://ci-rmtest.hi.inet/RepoRM_Binarios/',
    baseurl  => 'http://artifacts.hi.inet/Open_Web_Devices/push_server/commun/',

  }

  exec {"disable_epel":
    command =>"/bin/sed -i -e 's/enabled=1/enabled=0/g' /etc/yum.repos.d/epel.repo",
    require => Yumrepo["RepoRM_Binarios"],
  }

  package { 'mongo-10gen':
        ensure => installed,
        require => Yumrepo["RepoRM_Binarios"],
  }
  package { 'mongo-10gen-server':
        ensure => installed,
        require => Yumrepo["RepoRM_Binarios"],
  }
  file { "/home/mongo":
    ensure => "directory",
    mode   => 777,
    owner  => "mongod",
    group  => "mongod",
    require => Package["mongo-10gen-server"],
  }
  exec {"change_mongo_path":
    command => '/bin/sed -i -e "s/var\/lib\/mongo/home\/mongo/g" /etc/mongod.conf',
    require => File["/home/mongo"],
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
        require => [ Yumrepo["RepoRM_Binarios"], Exec["disable_epel"] ],
  }
  exec {"module_amqp":
    command =>"/usr/bin/sudo /usr/sbin/rabbitmq-plugins enable amqp_client",
    require => Package["rabbitmq-server"],
  }
  
  exec {"config_rabbit":
    command =>"/bin/echo '[{rabbit, [{disk_free_limit, {mem_relative, 0.1}}]}].' > /etc/rabbitmq/rabbitmq.config",
    require => Exec["module_amqp"],
  }
  exec {"start_rabbit":
    command =>"/usr/bin/nohup /usr/sbin/rabbitmq-server start  > /dev/null &",
    require => Exec["config_rabbit"],
  }
  yumrepo { 'Repo_PushServer':
    descr    => 'Repo del Push-Server',
    enabled  => 1,
    gpgcheck => 0,
    baseurl  => 'http://artifacts.hi.inet/Open_Web_Devices/push_server/1.0/candidate/',
  }
  package { 'PDI-OWD-Push_Server':
        ensure => installed,
        require => Yumrepo["Repo_PushServer"],
  }
  exec {"wait":
    command =>"/bin/sleep 1",
    require => Service["mongod"],
  }
  service { 'pushserverd':
    require => [ Package['PDI-OWD-Push_Server'], Exec["wait"] ],
    ensure => running,
    #enable => true,
  }
