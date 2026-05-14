# frozen_string_literal: true
require "rails_helper"

describe NotificationMailer, type: :mailer do
  subject(:notification_mailer) { NotificationMailer.with(user:, work_activity:) }

  let(:work) { FactoryBot.create(:shakespeare_and_company_work, group: Group.default) }
  let(:work_activity) { FactoryBot.create(:work_activity, work:) }
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

    context "when the message has markdown" do
      let(:work_activity) { FactoryBot.create(:work_activity, work:, message: "I like to send [links](https://www.google.com)") }
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

        expect(message.body.encoded).to include("To view the notification, please browse <a href='http://www.example.com/works/#{work.id}'>here<a>.")
        expect(message.body.encoded).to include("To view the notification, please browse <a href='http://www.example.com/works/#{work.id}'>here<a>.")
      end
    end

    context "when we are in production" do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it "shows the data commons url" do
        message = message_delivery.message
        text_part = message.text_part
        html_part = message.html_part
        expect(html_part.encoded).to include("To view the notification, please browse <a href='https://datacommons.princeton.edu/works/#{work.id}'>here<a>.")
        expect(text_part.encoded).to include("To view the notification, please browse to https://datacommons.princeton.edu/works/#{work.id}.")
      end
    end
  end

  describe "#new_submission_message" do
    let(:message_delivery) { notification_mailer.new_submission_message }

    it "generates the e-mail message" do
      expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
      expect(message_delivery.message).to be_a(Mail::Message)
      message = message_delivery.message
      expect(message.to).to be_an(Array)
      expect(message.to).to include(user.email)
      expect(message.from).to be_an(Array)
      expect(message.from).to include("noreply@example.com")
      expect(message.subject).to eq("[pdc-describe] New Submission Created")
      expect(message.body).to be_a(Mail::Body)
      expect(message.body.parts).to be_an(Mail::PartsList)
      expect(message.body.parts.first).to be_an(Mail::Part)
      expect(message.body.parts.first.content_type).to eq("text/plain; charset=UTF-8")
      expect(message.body.parts.last).to be_an(Mail::Part)
      expect(message.body.parts.last.content_type).to eq("text/html; charset=UTF-8")
      expect(message.body.encoded).to include("Hello #{user.given_name},")
      expect(message.body.encoded).to include("PDC Describe: New Submission Created")
      expect(message.body.encoded).to include("Thank you for creating a new submission")
      expect(message.body.encoded).to include("A curator will then be assigned to begin the curatorial review process")
      expect(message.body.encoded).to include("doi.org/#{work.doi}")
    end

    context "when the message has markdown" do
      let(:work_activity) { FactoryBot.create(:work_activity, work:) }
      it "generates the e-mail message" do
        expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
        expect(message_delivery.message).to be_a(Mail::Message)
        message = message_delivery.message
        expect(message.to).to eq([user.email])
        expect(message.from).to eq(["noreply@example.com"])
        expect(message.subject).to eq("[pdc-describe] New Submission Created")
        text_part = message.text_part
        html_part = message.html_part
        expect(html_part.content_type).to eq("text/html; charset=UTF-8")
        expect(text_part.content_type).to eq("text/plain; charset=UTF-8")

        expect(html_part.body.encoded).to include("Hello #{user.given_name},")
        expect(html_part.body.encoded).to include("Thank you for creating a new submission")
        expect(html_part.body.encoded).to include("A curator will then be assigned to begin the curatorial review process")
        expect(html_part.body.encoded).to include("doi.org/#{work.doi}")

        expect(text_part.body.encoded).to include("Hello #{user.given_name},")
        expect(text_part.body.encoded).to include("Thank you for creating a new submission")
        expect(text_part.body.encoded).to include("A curator will then be assigned to begin the curatorial review process")
        expect(text_part.body.encoded).to include("doi.org/#{work.doi}")
      end
    end
  end

  describe "#review_message" do
    let(:message_delivery) { notification_mailer.review_message }

    it "generates the e-mail message" do
      expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
      expect(message_delivery.message).to be_a(Mail::Message)
      message = message_delivery.message
      expect(message.to).to be_an(Array)
      expect(message.to).to include(user.email)
      expect(message.from).to be_an(Array)
      expect(message.from).to include("noreply@example.com")
      expect(message.subject).to eq("[pdc-describe] Submission Ready for Review")
      expect(message.body).to be_a(Mail::Body)
      expect(message.body.parts).to be_an(Mail::PartsList)
      expect(message.body.parts.first).to be_an(Mail::Part)
      expect(message.body.parts.first.content_type).to eq("text/plain; charset=UTF-8")
      expect(message.body.parts.last).to be_an(Mail::Part)
      expect(message.body.parts.last.content_type).to eq("text/html; charset=UTF-8")
      expect(message.body.encoded).to include("Hello #{user.given_name},")
      expect(message.body.encoded).to include("PDC Describe: Submission Ready for Review")
      expect(message.body.encoded).to include("a curator will be assigned shortly and begin the curatorial review process.")
      expect(message.body.encoded).to include("If you will need to embargo your dataset or need the data to be available for peer review, please include a note in dataset chat box.")
    end

    context "when the message has markdown" do
      let(:work_activity) { FactoryBot.create(:work_activity, work:, message: "I like to send [links](https://www.google.com)") }
      it "generates the e-mail message" do
        expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
        expect(message_delivery.message).to be_a(Mail::Message)
        message = message_delivery.message
        expect(message.to).to eq([user.email])
        expect(message.from).to eq(["noreply@example.com"])
        expect(message.subject).to eq("[pdc-describe] Submission Ready for Review")
        text_part = message.text_part
        html_part = message.html_part
        expect(text_part.content_type).to eq("text/plain; charset=UTF-8")
        expect(html_part.content_type).to eq("text/html; charset=UTF-8")
        expect(html_part.encoded).to include("Hello #{user.given_name},")
        expect(html_part.body.encoded).to include("Your submission <a href='http://www.example.com/works/#{work.id}'>#{work_activity.work.title}</a> has been received,")
        expect(html_part.body.encoded).to include("a curator will be assigned shortly and begin the curatorial review process.")
        expect(html_part.body.encoded).to include("If you will need to embargo your dataset or need the data to be available for peer review, please include a note in dataset chat box.")

        expect(text_part.body.encoded).to include("Hello #{user.given_name},")
        expect(text_part.body.encoded).to include("a curator will be assigned shortly and begin the curatorial review process.")
        expect(text_part.body.encoded).to include("If you will need to embargo your dataset or need the data to be available for peer review, please include a note in dataset chat box.")
      end
    end
  end

  describe "#reject_message" do
    let(:message_delivery) { notification_mailer.reject_message }

    it "generates the e-mail message" do
      expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
      expect(message_delivery.message).to be_a(Mail::Message)
      message = message_delivery.message
      expect(message.to).to be_an(Array)
      expect(message.to).to include(user.email)
      expect(message.from).to be_an(Array)
      expect(message.from).to include("noreply@example.com")
      expect(message.subject).to eq("[pdc-describe] Submission Returned")
      expect(message.body).to be_a(Mail::Body)
      expect(message.body.parts).to be_an(Mail::PartsList)
      expect(message.body.parts.first).to be_an(Mail::Part)
      expect(message.body.parts.first.content_type).to eq("text/plain; charset=UTF-8")
      expect(message.body.parts.last).to be_an(Mail::Part)
      expect(message.body.parts.last.content_type).to eq("text/html; charset=UTF-8")
      expect(message.body.encoded).to include("Hello #{user.given_name},")
      expect(message.body.encoded).to include("PDC Describe: Submission Returned")
    end

    context "when the message has markdown" do
      let(:work_activity) { FactoryBot.create(:work_activity, work:, message: "I like to send [links](https://www.google.com)") }
      it "generates the e-mail message" do
        expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
        expect(message_delivery.message).to be_a(Mail::Message)
        message = message_delivery.message
        expect(message.to).to eq([user.email])
        expect(message.from).to eq(["noreply@example.com"])
        expect(message.subject).to eq("[pdc-describe] Submission Returned")
        text_part = message.text_part
        html_part = message.html_part
        expect(text_part.content_type).to eq("text/plain; charset=UTF-8")
        expect(html_part.content_type).to eq("text/html; charset=UTF-8")
        expect(html_part.body.encoded).to include("Hello #{user.given_name},")
        expect(html_part.body.encoded).to include("has been returned to a draft state.")
        expect(text_part.body.encoded).to include("Hello #{user.given_name},")
        expect(text_part.body.encoded).to include("has been returned to a draft state.")
      end
    end
  end

  describe "#publish_message" do
    let(:message_delivery) { notification_mailer.publish_message }

    it "generates the e-mail message" do
      expect(message_delivery).to be_a(ActionMailer::Parameterized::MessageDelivery)
      expect(message_delivery.message).to be_a(Mail::Message)
      message = message_delivery.message
      expect(message.to).to be_an(Array)
      expect(message.to).to include(user.email)
      expect(message.from).to be_an(Array)
      expect(message.from).to include("noreply@example.com")
      expect(message.subject).to eq("[pdc-describe] Submission Published")
      expect(message.body).to be_a(Mail::Body)
      expect(message.body.parts).to be_an(Mail::PartsList)
      expect(message.body.parts.first).to be_an(Mail::Part)
      expect(message.body.parts.first.content_type).to eq("text/plain; charset=UTF-8")
      expect(message.body.parts.last).to be_an(Mail::Part)
      expect(message.body.parts.last.content_type).to eq("text/html; charset=UTF-8")
      expect(message.body.encoded).to include("Dear #{user.given_name},")
      expect(message.body.encoded).to include("Congratulations! Your dataset, #{work_activity.work.title}, has been published.")

      text_part = message.text_part
      expect(text_part.encoded).to include("Dear #{user.given_name},")
      expect(text_part.encoded).to include("Congratulations! Your dataset, #{work_activity.work.title}, has been published.")
    end

    context "when we are in production" do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it "shows the data commons url" do
        message = message_delivery.message
        text_part = message.text_part
        html_part = message.html_part
        expect(html_part.encoded).to include("Your DOI https://datacommons.princeton.edu/discovery/catalog/doi-#{work_activity.work.doi} will go live soon.")
        expect(text_part.encoded).to include("Your DOI https://datacommons.princeton.edu/discovery/catalog/doi-#{work_activity.work.doi} will go live soon.")
      end
    end
  end
end
