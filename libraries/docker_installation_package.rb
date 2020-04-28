module DockerCookbook
  class DockerInstallationPackage < DockerBase
    # Resource:: properties
    resource_name :docker_installation_package

    provides :docker_installation, platform: 'amazon'

    property :setup_docker_repo, [true, false], default: lazy { platform?('amazon') ? false : true }, desired_state: false
    property :repo_channel, String, default: 'stable'
    property :package_name, String, default: lazy { default_package_name }, desired_state: false
    property :package_version, String, default: lazy { version_string(version) }, desired_state: false
    property :version, String, default: lazy { default_docker_version }, desired_state: false
    property :package_options, String, desired_state: false

    # Actions
    action :create do
      if new_resource.setup_docker_repo
        if platform_family?('rhel', 'fedora')
          platform = platform?('fedora') ? 'fedora' : 'centos'
          arch = node['kernel']['machine']

          yum_repository 'Docker' do
            baseurl "https://download.docker.com/linux/#{platform}/#{node['platform_version'].to_i}/#{arch}/#{new_resource.repo_channel}"
            gpgkey "https://download.docker.com/linux/#{platform}/gpg"
            description "Docker #{new_resource.repo_channel.capitalize} repository"
            gpgcheck true
            enabled true
          end
        elsif platform_family?('debian')
          deb_arch =
            case node['kernel']['machine']
            when 'x86_64'
              'amd64'
            when 'aarch64'
              'arm64'
            when 'armv7l'
              'armhf'
            when 'ppc64le'
              'ppc64el'
            else
              node['kernel']['machine']
            end
          apt_repository 'Docker' do
            components Array(new_resource.repo_channel)
            uri "https://download.docker.com/linux/#{node['platform']}"
            arch deb_arch
            keyserver 'keyserver.ubuntu.com'
            key "https://download.docker.com/linux/#{node['platform']}/gpg"
            action :add
          end
        else
          Chef::Log.warn("Cannot setup the Docker repo for platform #{node['platform']}. Skipping.")
        end
      end

      package new_resource.package_name do
        version new_resource.package_version unless amazon?
        options new_resource.package_options
        action :install
      end
    end

    action :delete do
      package new_resource.package_name do
        action :remove
      end
    end

    # These are helpers for the properties so they are not in an action class
    def default_docker_version
      '19.03.5'
    end

    def default_package_name
      return 'docker' if amazon?
      'docker-ce'
    end

    def el7?
      return true if node['platform_family'] == 'rhel' && node['platform_version'].to_i == 7
      false
    end

    def fedora?
      return true if node['platform'] == 'fedora'
      false
    end

    def debuntu?
      return true if node['platform_family'] == 'debian'
      false
    end

    def debian?
      return true if node['platform'] == 'debian'
      false
    end

    def ubuntu?
      return true if node['platform'] == 'ubuntu'
      false
    end

    def stretch?
      return true if node['platform'] == 'debian' && node['platform_version'].to_i == 9
      false
    end

    def buster?
      return true if node['platform'] == 'debian' && node['platform_version'].to_i == 10
      false
    end

    def xenial?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '16.04'
      false
    end

    def bionic?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '18.04'
      false
    end

    def focal?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '20.04'
      false
    end

    def amazon?
      return true if node['platform'] == 'amazon'
      false
    end

    # https://github.com/chef/chef/issues/4103
    def version_string(v)
      codename = if stretch? # deb 9
                   'stretch'
                 elsif buster? # deb 10
                   'buster'
                 elsif xenial? # ubuntu 16.04
                   'xenial'
                 elsif bionic? # ubuntu 18.04
                   'bionic'
                 elsif focal? # ubuntu 20.04
                   'focal'
                 end

      # https://github.com/seemethere/docker-ce-packaging/blob/9ba8e36e8588ea75209d813558c8065844c953a0/deb/gen-deb-ver#L16-L20
      test_version = '3'

      if v.to_f < 17.06 && debuntu?
        return "#{v}~ce-0~debian-#{codename}" if debian?
        return "#{v}~ce-0~ubuntu-#{codename}" if ubuntu?
      elsif v == '17.03.3' && el7?
        "#{v}.ce-1.el7"
      elsif v.to_f < 18.06 && !bionic?
        return "#{v}.ce-1.el7.centos" if el7?
        return "#{v}~ce-0~debian" if debian?
        return "#{v}~ce-0~ubuntu" if ubuntu?
      elsif v.to_f >= 18.09 && debuntu?
        return "5:#{v}~#{test_version}-0~debian-#{codename}" if debian?
        return "5:#{v}~#{test_version}-0~ubuntu-#{codename}" if ubuntu?
      elsif v.to_f >= 18.09 && el7?
        "#{v}-#{test_version}.el7"
      elsif v.to_f >= 18.09 && fedora?
        v.to_s
      else
        return "#{v}.ce" if fedora?
        return "#{v}.ce-#{test_version}.el7" if el7?
        return "#{v}~ce~#{test_version}-0~debian" if debian?
        return "#{v}~ce~#{test_version}-0~ubuntu" if ubuntu?
        v
      end
    end
  end
end
