# frozen_string_literal: true
require "rails_helper"

RSpec.describe RegistrationsMailer, type: :mailer do
  let(:delegate1) { FactoryGirl.create :delegate }
  let(:delegate2) { FactoryGirl.create :delegate }
  let(:organizer1) { FactoryGirl.create :user }
  let(:organizer2) { FactoryGirl.create :user }
  let(:competition_without_organizers) { FactoryGirl.create(:competition, :registration_open, delegates: [delegate1, delegate2]) }
  let(:competition_with_organizers) { FactoryGirl.create(:competition, :registration_open, delegates: [delegate1, delegate2], organizers: [organizer1, organizer2]) }

  describe "notify_organizers_of_new_registration" do
    let(:registration) { FactoryGirl.create(:registration, competition: competition_without_organizers) }
    let(:mail) { RegistrationsMailer.notify_organizers_of_new_registration(registration) }

    it "renders the headers" do
      competition_delegate2 = competition_without_organizers.competition_delegates.find_by_delegate_id(delegate2.id)
      competition_delegate2.receive_registration_emails = false
      competition_delegate2.save!

      expect(mail.subject).to eq("#{registration.name} just registered for #{registration.competition.name}")
      expect(mail.to).to eq([delegate1.email])
      expect(mail.reply_to).to eq([registration.user.email])
      expect(mail.from).to eq(["notifications@worldcubeassociation.org"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match(edit_registration_url(registration))
    end

    it "handles no organizers receiving email" do
      competition_delegate1 = competition_without_organizers.competition_delegates.find_by_delegate_id(delegate1.id)
      competition_delegate1.receive_registration_emails = false
      competition_delegate1.save!

      competition_delegate2 = competition_without_organizers.competition_delegates.find_by_delegate_id(delegate2.id)
      competition_delegate2.receive_registration_emails = false
      competition_delegate2.save!

      expect(mail.message).to be_kind_of ActionMailer::Base::NullMail
    end
  end

  describe "notify_organizers_of_deleted_registration" do
    let(:registration) { FactoryGirl.create(:registration, competition: competition_without_organizers) }
    let(:mail) { RegistrationsMailer.notify_organizers_of_deleted_registration(registration) }

    it "renders the headers" do
      expect(mail.subject).to eq("#{registration.name} just deleted their registration for #{registration.competition.name}")
      expect(mail.to).to eq([delegate1.email, delegate2.email])
      expect(mail.reply_to).to eq(competition_without_organizers.managers.map(&:email))
      expect(mail.from).to eq(["notifications@worldcubeassociation.org"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("just deleted their registration for #{registration.competition.name}")
    end
  end

  describe "notify_registrant_of_new_registration for competition without organizers" do
    let(:registration) { FactoryGirl.create(:registration, competition: competition_without_organizers) }
    let!(:earlier_registration) { FactoryGirl.create(:registration, competition: competition_without_organizers) }
    let(:mail) { RegistrationsMailer.notify_registrant_of_new_registration(registration) }

    it "renders the headers" do
      expect(mail.subject).to eq("You have registered for #{registration.competition.name}")
      expect(mail.to).to eq([registration.email])
      expect(mail.reply_to).to eq(competition_without_organizers.delegates.map(&:email))
      expect(mail.from).to eq(["notifications@worldcubeassociation.org"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Your registration is on the waiting list, which currently has 2 people on it.")
      expect(mail.body.encoded).to match(competition_register_url(registration.competition))
      expect(mail.body.encoded).to match("Regards, #{users_to_sentence(competition_without_organizers.organizers_or_delegates)}.")
    end

    it "pluralizes correctly" do
      earlier_registration.destroy!

      expect(mail.body.encoded).to match("which currently has 1 person on it.")
      expect(mail.body.encoded).to match(competition_register_url(registration.competition))
    end
  end

  describe "notify_registrant_of_new_registration for competition with organizers" do
    let(:registration) { FactoryGirl.create(:registration, competition: competition_with_organizers) }
    let(:mail) { RegistrationsMailer.notify_registrant_of_new_registration(registration) }

    it "sets organizers in the reply_to" do
      expect(mail.reply_to).to eq(competition_with_organizers.organizers.map(&:email))
    end

    it "displays organizer names in the signature" do
      names = competition_with_organizers.organizers.map(&:name).map { |n| ERB::Util.html_escape(n) }.sort
      expect(mail.body.encoded).to match("Regards, #{names.to_sentence}\\.")
    end
  end

  describe "notify_registrant_of_accepted_registration for competition without organizers" do
    let(:mail) { RegistrationsMailer.notify_registrant_of_accepted_registration(registration) }
    let(:registration) { FactoryGirl.create(:registration, competition: competition_without_organizers) }

    it "renders the headers" do
      expect(mail.subject).to eq("Your registration for #{registration.competition.name} has been accepted")
      expect(mail.to).to eq([registration.email])
      expect(mail.reply_to).to eq(competition_without_organizers.delegates.map(&:email))
      expect(mail.from).to eq(["notifications@worldcubeassociation.org"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Your registration for .{1,200}#{registration.competition.name}.{1,200} has been accepted")
    end
  end

  describe "notify_registrant_of_accepted_registration for competition with organizers" do
    let(:mail) { RegistrationsMailer.notify_registrant_of_accepted_registration(registration) }
    let(:registration) { FactoryGirl.create(:registration, competition: competition_with_organizers) }

    it "sets organizers in the reply_to" do
      expect(mail.reply_to).to eq(competition_with_organizers.organizers.map(&:email))
    end

    it "displays organizer names in the signature" do
      names = competition_with_organizers.organizers.map(&:name).map { |n| ERB::Util.html_escape(n) }.sort
      expect(mail.body.encoded).to match("Regards, #{names.to_sentence}\\.")
    end
  end

  describe "notify_registrant_of_pending_registration for a competition without organizers" do
    let(:mail) { RegistrationsMailer.notify_registrant_of_pending_registration(registration) }
    let(:registration) { FactoryGirl.create(:registration, competition: competition_without_organizers) }

    it "renders the headers" do
      expect(mail.subject).to eq("You have been moved to the waiting list for #{registration.competition.name}")
      expect(mail.to).to eq([registration.email])
      expect(mail.reply_to).to eq(competition_without_organizers.delegates.map(&:email))
      expect(mail.from).to eq(["notifications@worldcubeassociation.org"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Your registration for .{1,200}#{registration.competition.name}.{1,200} has been moved to the waiting list")
      expect(mail.body.encoded).to match("If you think this is an error, please reply to this email.")
      names = competition_without_organizers.delegates.map(&:name).map { |n| ERB::Util.html_escape(n) }.sort
      expect(mail.body.encoded).to match("Regards, #{names.to_sentence}\\.")
    end
  end

  describe "notify_registrant_of_pending_registration for a competition with organizers" do
    let(:mail) { RegistrationsMailer.notify_registrant_of_pending_registration(registration) }
    let(:registration) { FactoryGirl.create(:registration, competition: competition_with_organizers) }

    it "sets organizers in the reply_to" do
      expect(mail.reply_to).to eq(competition_with_organizers.organizers.map(&:email))
    end

    it "displays organizer names in the signature" do
      names = competition_with_organizers.organizers.map(&:name).map { |n| ERB::Util.html_escape(n) }.sort
      expect(mail.body.encoded).to match("Regards, #{names.to_sentence}\\.")
    end
  end

  describe "notify_registrant_of_deleted_registration for a competition without organizers" do
    let(:mail) { RegistrationsMailer.notify_registrant_of_deleted_registration(registration) }
    let(:registration) { FactoryGirl.create(:registration, competition: competition_without_organizers) }

    it "renders the headers" do
      expect(mail.subject).to eq("Your registration for #{registration.competition.name} has been deleted")
      expect(mail.to).to eq([registration.email])
      expect(mail.reply_to).to eq(competition_without_organizers.delegates.map(&:email))
      expect(mail.from).to eq(["notifications@worldcubeassociation.org"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Your registration for .{1,200}#{registration.competition.name}.{1,200} has been deleted")
      names = competition_without_organizers.delegates.map(&:name).map { |n| ERB::Util.html_escape(n) }.sort
      expect(mail.body.encoded).to match("Regards, #{names.to_sentence}\\.")
    end
  end

  describe "notify_registrant_of_deleted_registration for a competition with organizers" do
    let(:mail) { RegistrationsMailer.notify_registrant_of_deleted_registration(registration) }
    let(:registration) { FactoryGirl.create(:registration, competition: competition_with_organizers) }

    it "renders the headers" do
      expect(mail.reply_to).to eq(competition_with_organizers.organizers.map(&:email))
    end

    it "renders the body" do
      names = competition_with_organizers.organizers.map(&:name).map { |n| ERB::Util.html_escape(n) }.sort
      expect(mail.body.encoded).to match("Regards, #{names.to_sentence}\\.")
    end
  end
end
