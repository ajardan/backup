# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

module Backup
describe 'Database::Redis' do
  specify 'No SAVE, no Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Redis do |db|
          db.path = '/var/lib/redis'
        end
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.logger.has_warnings? ).to be_false
    expect( job.logger.has_errors? ).to be_false

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      5774  my_backup/databases/Redis/dump.rdb
    ])
  end

  specify 'SAVE, no Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Redis do |db|
          db.path = '/var/lib/redis'
          db.invoke_save = true
        end
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.logger.has_warnings? ).to be_false
    expect( job.logger.has_errors? ).to be_false

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      5774  my_backup/databases/Redis/dump.rdb
    ])
  end

  specify 'SAVE, with Compression' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        database Redis do |db|
          db.path = '/var/lib/redis'
          db.invoke_save = true
        end
        compress_with Gzip
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.logger.has_warnings? ).to be_false
    expect( job.logger.has_errors? ).to be_false

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      1920..1930  my_backup/databases/Redis/dump.rdb.gz
    ])
  end
end
end
