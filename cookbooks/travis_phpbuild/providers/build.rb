action :create do
  unless exists?
    Chef::Log.info("Installing PHP #{@new_resource.version} with php-build")
    new_resource  = @new_resource
    phpbuild_path = "#{node['travis_build_environment']['home']}/.php-build"
    version       = new_resource.version
    target_path   = "#{new_resource.path}/#{version}"
    pear_option   = @new_resource.with_pear ? '--pear' : ''

    bash "install PHP #{version} with php-build" do
      user new_resource.owner
      group new_resource.group
      # LDFLAGS are necessary to solve PHP 5.3 issues with the intl extension,
      # which is crucial for Symfony among other projects. MK.
      environment(
        'HOME' => node['travis_build_environment']['home'],
        'LDFLAGS' => '-lstdc++',
        'PHP_VERSION' => version
      )
      cwd "#{phpbuild_path}/bin"
      code <<-EOF.gsub(/^\s+>\s/, '')
        > ./php-build -i #{version < '5.3' ? 'dist' : 'development'} \\
        >   #{pear_option} #{version} #{target_path}
      EOF
    end

    template "#{target_path}/etc/conf.d/travis.ini" do
      owner new_resource.owner
      group new_resource.group
      cookbook 'travis_phpbuild'
      source 'travis.ini.erb'
      variables(
        timezone: node['travis_phpbuild']['custom']['php_ini']['timezone'],
        memory_limit: node['travis_phpbuild']['custom']['php_ini']['memory_limit']
      )
    end

    new_resource.updated_by_last_action(true)
  end
end

action :delete do
  if exists?
    Chef::Log.info("Uninstalling PHP #{@new_resource.version} from php-build")
    target_path = "#{@new_resource.path}/#{@new_resource.version}"

    FileUtils.rm_rf(target_path)
    new_resource.updated_by_last_action(true)
  end
end

private

def exists?
  target_path = "#{@new_resource.path}/#{@new_resource.version}"

  ::File.exist?(target_path) && ::File.directory?(target_path) \
    && ::File.exists?("#{target_path}/bin/php")
end
