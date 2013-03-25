# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Mail do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::Mail.new(model) do |mail|
      mail.delivery_method      = :smtp
      mail.from                 = 'my.sender.email@gmail.com'
      mail.to                   = 'my.receiver.email@gmail.com'
      mail.address              = 'smtp.gmail.com'
      mail.port                 = 587
      mail.domain               = 'your.host.name'
      mail.user_name            = 'user'
      mail.password             = 'secret'
      mail.authentication       = 'plain'
      mail.encryption           = :starttls

      mail.sendmail             = '/path/to/sendmail'
      mail.sendmail_args        = '-i -t -X/tmp/traffic.log'
      mail.exim                 = '/path/to/exim'
      mail.exim_args            = '-i -t -X/tmp/traffic.log'

      mail.mail_folder          = '/path/to/backup/mails'
    end
  end

  describe '#initialize' do
    after { Backup::Notifier::Mail.clear_defaults! }

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        notifier.delivery_method.should      == :smtp
        notifier.from.should                 == 'my.sender.email@gmail.com'
        notifier.to.should                   == 'my.receiver.email@gmail.com'
        notifier.address.should              == 'smtp.gmail.com'
        notifier.port.should                 == 587
        notifier.domain.should               == 'your.host.name'
        notifier.user_name.should            == 'user'
        notifier.password.should             == 'secret'
        notifier.authentication.should       == 'plain'
        notifier.encryption.should           == :starttls

        notifier.sendmail.should             == '/path/to/sendmail'
        notifier.sendmail_args.should        == '-i -t -X/tmp/traffic.log'
        notifier.exim.should                 == '/path/to/exim'
        notifier.exim_args.should            == '-i -t -X/tmp/traffic.log'

        notifier.mail_folder.should          == '/path/to/backup/mails'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'should use default values if none are given' do
        notifier = Backup::Notifier::Mail.new(model)
        notifier.delivery_method.should       be_nil
        notifier.from.should                  be_nil
        notifier.to.should                    be_nil
        notifier.address.should               be_nil
        notifier.port.should                  be_nil
        notifier.domain.should                be_nil
        notifier.user_name.should             be_nil
        notifier.password.should              be_nil
        notifier.authentication.should        be_nil
        notifier.encryption.should            be_nil

        notifier.sendmail.should              be_nil
        notifier.sendmail_args.should         be_nil
        notifier.exim.should                  be_nil
        notifier.exim_args.should             be_nil

        notifier.mail_folder.should           be_nil

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::Mail.defaults do |n|
          n.delivery_method = :file
          n.from       = 'default.sender@domain.com'
          n.to         = 'some.receiver@domain.com'
          n.on_success = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier = Backup::Notifier::Mail.new(model)
        notifier.delivery_method.should       == :file
        notifier.from.should                  == 'default.sender@domain.com'
        notifier.to.should                    == 'some.receiver@domain.com'
        notifier.address.should               be_nil
        notifier.port.should                  be_nil
        notifier.domain.should                be_nil
        notifier.user_name.should             be_nil
        notifier.password.should              be_nil
        notifier.authentication.should        be_nil
        notifier.encryption.should            be_nil

        notifier.sendmail.should              be_nil
        notifier.sendmail_args.should         be_nil
        notifier.exim.should                  be_nil
        notifier.exim_args.should             be_nil

        notifier.mail_folder.should           be_nil

        notifier.on_success.should == false
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'should override pre-configured defaults' do
        notifier = Backup::Notifier::Mail.new(model) do |n|
          n.delivery_method = :sendmail
          n.from       = 'new.sender@domain.com'
          n.to         = 'new.receiver@domain.com'
          n.port       = 123
          n.on_warning = false
        end

        notifier.delivery_method.should == :sendmail
        notifier.from.should == 'new.sender@domain.com'
        notifier.to.should   == 'new.receiver@domain.com'
        notifier.port.should == 123

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == true
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#notify!' do
    let(:template) { mock }
    let(:message) { '[Backup::%s] test label (test_trigger)' }

    before do
      notifier.instance_variable_set(:@template, template)
      notifier.delivery_method = :test
      ::Mail::TestMailer.deliveries.clear

      Backup::Logger.stubs(:messages).returns([
        stub(:formatted_lines => ['line 1', 'line 2']),
        stub(:formatted_lines => ['line 3'])
      ])
    end

    context 'when status is :success' do
      it 'should send a Success email with no attachments' do
        template.expects(:result).
            with('notifier/mail/success.erb').
            returns('message body')

        notifier.send(:notify!, :success)

        sent_message = ::Mail::TestMailer.deliveries.first
        sent_message.subject.should == message % 'Success'
        sent_message.multipart?.should be_false
        sent_message.body.should == 'message body'
        sent_message.has_attachments?.should be_false
      end
    end

    context 'when status is :warning' do
      it 'should send a Warning email with an attached log' do
        template.expects(:result).
            with('notifier/mail/warning.erb').
            returns('message body')

        notifier.send(:notify!, :warning)

        sent_message = ::Mail::TestMailer.deliveries.first
        sent_message.subject.should == message % 'Warning'
        sent_message.body.multipart?.should be_true
        sent_message.text_part.decoded.should == 'message body'
        sent_message.attachments["#{model.time}.#{model.trigger}.log"].
            read.should == "line 1\nline 2\nline 3"
      end
    end

    context 'when status is :failure' do
      it 'should send a Failure email with an attached log' do
        template.expects(:result).
            with('notifier/mail/failure.erb').
            returns('message body')

        notifier.send(:notify!, :failure)

        sent_message = ::Mail::TestMailer.deliveries.first
        sent_message.subject.should == message % 'Failure'
        sent_message.body.multipart?.should be_true
        sent_message.text_part.decoded.should == 'message body'
        sent_message.attachments["#{model.time}.#{model.trigger}.log"].
            read.should == "line 1\nline 2\nline 3"
      end
    end
  end # describe '#notify!'

  describe '#new_email' do
    context 'when no delivery_method is set' do
      before { notifier.delivery_method = nil }
      it 'should default to :smtp' do
        email = notifier.send(:new_email)
        email.should be_an_instance_of ::Mail::Message
        email.delivery_method.should be_an_instance_of ::Mail::SMTP
      end
    end

    context 'when delivery_method is :smtp' do
      before { notifier.delivery_method = :smtp }

      it 'should return an email using SMTP' do
        email = notifier.send(:new_email)
        email.delivery_method.should be_an_instance_of ::Mail::SMTP
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)

        email.to.should   == ['my.receiver.email@gmail.com']
        email.from.should == ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        settings[:address].should               == 'smtp.gmail.com'
        settings[:port].should                  == 587
        settings[:domain].should                == 'your.host.name'
        settings[:user_name].should             == 'user'
        settings[:password].should              == 'secret'
        settings[:authentication].should        == 'plain'
        settings[:enable_starttls_auto].should  be(true)
        settings[:openssl_verify_mode].should   be_nil
        settings[:ssl].should                   be(false)
        settings[:tls].should                   be(false)
      end

      it 'should properly set other encryption settings' do
        notifier.encryption = :ssl
        email = notifier.send(:new_email)
        settings = email.delivery_method.settings
        settings[:enable_starttls_auto].should  be(false)
        settings[:ssl].should                   be(true)
        settings[:tls].should                   be(false)

        notifier.encryption = :tls
        email = notifier.send(:new_email)
        settings = email.delivery_method.settings
        settings[:enable_starttls_auto].should  be(false)
        settings[:ssl].should                   be(false)
        settings[:tls].should                   be(true)
      end
    end

    context 'when delivery_method is :sendmail' do
      before { notifier.delivery_method = :sendmail }
      it 'should return an email using Sendmail' do
        email = notifier.send(:new_email)
        email.delivery_method.should be_an_instance_of ::Mail::Sendmail
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)

        email.to.should   == ['my.receiver.email@gmail.com']
        email.from.should == ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        settings[:location].should  == '/path/to/sendmail'
        settings[:arguments].should == '-i -t -X/tmp/traffic.log'
      end
    end

    context 'when delivery_method is :exim' do
      before { notifier.delivery_method = :exim }
      it 'should return an email using Exim' do
        email = notifier.send(:new_email)
        email.delivery_method.should be_an_instance_of ::Mail::Exim
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)

        email.to.should   == ['my.receiver.email@gmail.com']
        email.from.should == ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        settings[:location].should  == '/path/to/exim'
        settings[:arguments].should == '-i -t -X/tmp/traffic.log'
      end
    end

    context 'when delivery_method is :file' do
      before { notifier.delivery_method = :file }
      it 'should return an email using FileDelievery' do
        email = notifier.send(:new_email)
        email.delivery_method.should be_an_instance_of ::Mail::FileDelivery
      end

      it 'should set the proper options' do
        email = notifier.send(:new_email)

        email.to.should   == ['my.receiver.email@gmail.com']
        email.from.should == ['my.sender.email@gmail.com']

        settings = email.delivery_method.settings
        settings[:location].should  == '/path/to/backup/mails'
      end
    end
  end # describe '#new_email'

  describe 'deprecations' do
    describe '#enable_starttls_auto' do
      before do
        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of Backup::Errors::ConfigurationError
          err.message.should match(
            /Use #encryption instead/
          )
        }
      end

      it 'warns and transfers true value' do
        notifier = Backup::Notifier::Mail.new(model) do |mail|
          mail.enable_starttls_auto = true
        end
        notifier.encryption.should == :starttls
      end

      it 'warns and transfers false value' do
        notifier = Backup::Notifier::Mail.new(model) do |mail|
          mail.enable_starttls_auto = false
        end
        notifier.encryption.should == :none
      end
    end
  end # describe 'deprecations'
end
