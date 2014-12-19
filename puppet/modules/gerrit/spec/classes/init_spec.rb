require 'spec_helper'

describe "gerrit" do
    let(:title) { 'gerrit' }
    context 'gerrit' do
        it {
            should contain_user('gerrit').with({
                'ensure' => 'present',
#                'gid'    => 'gerrit',
#                'home'   => '/home/gerrit',
            })
            should contain_group('gerrit')
            should contain_package('openjdk-7-jre')
            should contain_file('/home/gerrit/site_path').with({
                'ensure' => 'directory',
                'owner'  => 'gerrit',
            })
            should contain_file('/home/gerrit/site_path/etc').with({
                'ensure' => 'directory',
                'owner'  => 'gerrit',
            })
            should contain_file('/home/gerrit/site_path/hooks').with({
                'ensure' => 'directory',
                'owner'  => 'gerrit',
            })
 
            should contain_file('/home/gerrit/site_path/lib').with({
                'ensure' => 'directory',
                'owner'  => 'gerrit',
            })
 

            should contain_file('/home/gerrit/site_path/etc/gerrit.config').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0640',
            })

            should contain_file('/home/gerrit/site_path/etc/secure.config').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0600',
            })
            
            should contain_file('/home/gerrit/site_path/hooks/hooks.config').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0600',
            })
            
            should contain_file('/home/gerrit/site_path/etc/ssh_host_rsa_key').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0600',
            })
            
            should contain_file('/home/gerrit/site_path/etc/ssh_host_rsa_key.pub').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0640',
            })
            
            should contain_file('/root/gerrit-firstuser-init.sql').with({
                'ensure'  => 'present',
                'mode'    => '0640',
            })
            
            should contain_file('/root/gerrit-firstuser-init.sh').with({
                'ensure'  => 'present',
                'mode'    => '0700',
            })
            
            should contain_file('/root/gerrit-set-default-acl.sh').with({
                'ensure'  => 'present',
                'mode'    => '0700',
            })
            
            should contain_file('/root/gerrit-set-jenkins-user.sh').with({
                'ensure'  => 'present',
                'mode'    => '0700',
            })
            
            should contain_file('/home/gerrit/gerrit.war').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0640',
            })
            
            should contain_file('/home/gerrit/site_path/lib/mysql-connector-java.jar').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
            })
            
            should contain_file('/home/gerrit/site_path/lib/bcprov.jar').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
            })

            should contain_file('/home/gerrit/site_path/lib/bcpkix.jar').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
            })
 
            
            should contain_file('/home/gerrit/site_path/hooks/patchset-created').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0740',
            })
            
            should contain_file('/home/gerrit/site_path/hooks/change-merged').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0740',
            })
            
            should contain_file('/etc/init.d/gerrit').with({
                'ensure'  => 'link',
                'target'  => '/home/gerrit/site_path/bin/gerrit.sh',
            })
            
            should contain_file('/etc/default/gerritcodereview').with({
                'ensure'  => 'present',
                'owner'   => 'gerrit',
                'group'   => 'gerrit',
                'mode'    => '0644',
            })
            should contain_file('/etc/monit/conf.d/gerrit') 
        }
    end
end


