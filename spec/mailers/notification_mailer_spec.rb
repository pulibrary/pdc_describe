# frozen_string_literal: true
require "rails_helper"

describe NotificationMailer, type: :mailer do
  subject(:notification_mailer) { NotificationMailer.with(user: user, work_activity: work_activity) }

  let(:work) { FactoryBot.create(:work, group: Group.default) }
  let(:work_activity) { FactoryBot.create(:work_activity, work: work) }
  let(:user) { work_activity.created_by_user }

  describe "#build_message" do
    let(:message_delivery) { notification_mailer.build_message }

    it "generates the e-mail message" do
      expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
      expect(message_delivery.message).to be_a(Mail::Message)
      message = message_delivery.message
      expect(message.to).to be_an(Array)
      expect(message.to).to include(user.email)
      expect(message.from).to be_an(Array)
      expect(message.from).to include("noreply@example.com")
      expect(message.subject).to eq("[pdc-describe] New Notification")
      expect(message.body).to be_a(Mail::Body)
      expect(message.body.parts).to be_an(Mail::PartsList)
      expect(message.body.parts.first).to be_an(Mail::Part)
      expect(message.body.parts.first.content_type).to eq("text/plain; charset=UTF-8")
      expect(message.body.parts.last).to be_an(Mail::Part)
      expect(message.body.parts.last.content_type).to eq("text/html; charset=UTF-8")
      expect(message.body.encoded).to include("Hello #{user.given_name},")
      expect(message.body.encoded).to include(work_activity.message)
      expect(message.body.encoded).to include("To view the notification, please browse <a href='http://www.example.com/works/#{work.id}'>here<a>.")
    end

    context "when the mesage has markdown" do
      let(:work_activity) { FactoryBot.create(:work_activity, work: work, message: "I like to send [links](https://www.google.com)") }
      it "generates the e-mail message" do
        expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
        expect(message_delivery.message).to be_a(Mail::Message)
        message = message_delivery.message
        expect(message.to).to eq([user.email])
        expect(message.from).to eq(["noreply@example.com"])
        expect(message.subject).to eq("[pdc-describe] New Notification")
        text_part = message.text_part
        html_part = message.html_part
        expect(text_part.content_type).to eq("text/plain; charset=UTF-8")
        expect(html_part.content_type).to eq("text/html; charset=UTF-8")
        expect(html_part.encoded).to include("Hello #{user.given_name},")
        expect(html_part.encoded).to include("To view the notification, please browse <a href='http://www.example.com/works/#{work.id}'>here<a>.")
        expect(html_part.encoded).to include("I like to send <a href=\"https://www.google.com\">links</a>")
        expect(text_part.encoded).to include(work_activity.message)
        expect(text_part.encoded).to include("Hello #{user.given_name},")
        expect(text_part.encoded).to include("To view the notification, please browse to http://www.example.com/works/#{work.id}.")
      end
    end
  end
end
