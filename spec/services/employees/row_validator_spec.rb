require "rails_helper"

RSpec.describe Employees::RowValidator do
  def valid_row(overrides = {})
    {
      "first_name"        => "Jane",
      "last_name"         => "Doe",
      "email"             => "jane.doe@example.com",
      "date_of_birth"     => "15/08/1990",
      "joining_date"      => "15/08/2023",
      "employment_status" => "active"
    }.merge(overrides)
  end

  subject(:result) { described_class.new(row).call }

  context "with a fully valid row" do
    let(:row) { valid_row }

    it { expect(result[:valid]).to be true }
    it { expect(result[:errors]).to be_empty }
  end

  describe "required fields" do
    %w[first_name last_name email date_of_birth joining_date employment_status].each do |field|
      context "when #{field} is blank" do
        let(:row) { valid_row(field => "") }

        it "adds a presence error" do
          expect(result[:errors]).to include(match(/#{field.humanize}/i))
        end
      end
    end
  end

  describe "email format" do
    context "with an invalid email" do
      let(:row) { valid_row("email" => "not-an-email") }

      it { expect(result[:errors]).to include("Email is not valid") }
    end

    context "with a blank email" do
      let(:row) { valid_row("email" => "") }

      it "does not add a format error (presence error covers it)" do
        expect(result[:errors]).not_to include("Email is not valid")
      end
    end
  end

  describe "date fields" do
    %w[joining_date date_of_birth confirmation_date].each do |field|
      context "when #{field} has wrong format" do
        let(:row) { valid_row(field => "2023-08-15") }

        it "adds a format error" do
          expect(result[:errors]).to include(match(/#{field.humanize}.*DD\/MM\/YYYY/i))
        end
      end

      context "when #{field} is blank" do
        let(:row) { valid_row(field => "") }

        it "skips validation" do
          errors_for_field = result[:errors].select { |e| e.include?(field.humanize) }
          expect(errors_for_field).to be_empty unless %w[joining_date date_of_birth].include?(field)
        end
      end
    end
  end

  describe "employment_status" do
    context "with an invalid status" do
      let(:row) { valid_row("employment_status" => "fired") }

      it { expect(result[:errors]).to include(match(/Employment status must be one of/)) }
    end

    context "with each valid status" do
      Employee::EMPLOYMENT_STATUSES.each do |status|
        it "accepts '#{status}'" do
          row = valid_row("employment_status" => status)
          expect(described_class.new(row).call[:errors]).not_to include(match(/Employment status/))
        end
      end
    end
  end

  describe "gender" do
    context "with an invalid gender" do
      let(:row) { valid_row("gender" => "unknown") }

      it { expect(result[:errors]).to include(match(/Gender must be one of/)) }
    end

    context "when blank" do
      let(:row) { valid_row("gender" => "") }

      it "skips validation" do
        expect(result[:errors]).not_to include(match(/Gender/))
      end
    end
  end

  describe "PAN number" do
    context "with invalid format" do
      let(:row) { valid_row("pan_number" => "INVALID") }

      it { expect(result[:errors]).to include("PAN must be in format ABCDE1234F") }
    end

    context "with valid PAN" do
      let(:row) { valid_row("pan_number" => "ABCDE1234F") }

      it { expect(result[:errors]).not_to include(match(/PAN/)) }
    end

    context "when blank" do
      let(:row) { valid_row("pan_number" => "") }

      it { expect(result[:errors]).not_to include(match(/PAN/)) }
    end
  end

  describe "Aadhaar number" do
    context "with fewer than 12 digits" do
      let(:row) { valid_row("aadhaar_number" => "12345") }

      it { expect(result[:errors]).to include("Aadhaar must be 12 digits") }
    end

    context "with 12 digits" do
      let(:row) { valid_row("aadhaar_number" => "123456789012") }

      it { expect(result[:errors]).not_to include(match(/Aadhaar/)) }
    end
  end

  describe "pincode" do
    context "with fewer than 6 digits" do
      let(:row) { valid_row("pincode" => "4000") }

      it { expect(result[:errors]).to include("Pincode must be 6 digits") }
    end

    context "with 6 digits" do
      let(:row) { valid_row("pincode" => "400001") }

      it { expect(result[:errors]).not_to include(match(/Pincode/)) }
    end
  end
end
