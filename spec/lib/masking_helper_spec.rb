require 'rails_helper'

RSpec.describe 'MaskingHelper' do
  let(:masking_helper) do
    Class.new do
      include Maskable
      
      def initialize
        # Mock class for testing
      end
    end.new
  end

  describe '#mask_email_value' do
    context 'with minimal pattern' do
      it 'masks email showing first character and domain' do
        result = masking_helper.send(:mask_email_value, 'john.doe@example.com', 'minimal')
        expect(result).to eq('j***@example.com')
      end

      it 'handles short email addresses' do
        result = masking_helper.send(:mask_email_value, 'a@test.com', 'minimal')
        expect(result).to eq('a***@test.com')
      end
    end

    context 'with standard pattern' do
      it 'masks email showing first and last character with partial domain' do
        result = masking_helper.send(:mask_email_value, 'john.doe@example.com', 'standard')
        expect(result).to eq('j***e@e***.com')
      end

      it 'handles short local part' do
        result = masking_helper.send(:mask_email_value, 'ab@test.com', 'standard')
        expect(result).to eq('***@t***.com')
      end

      it 'handles single character local part' do
        result = masking_helper.send(:mask_email_value, 'a@test.com', 'standard')
        expect(result).to eq('***@t***.com')
      end
    end

    context 'with complete pattern' do
      it 'completely hides the email' do
        result = masking_helper.send(:mask_email_value, 'john.doe@example.com', 'complete')
        expect(result).to eq('*** HIDDEN ***')
      end
    end

    context 'with invalid email' do
      it 'returns original value for invalid email format' do
        result = masking_helper.send(:mask_email_value, 'invalid-email', 'standard')
        expect(result).to eq('invalid-email')
      end

      it 'returns nil for nil input' do
        result = masking_helper.send(:mask_email_value, nil, 'standard')
        expect(result).to be_nil
      end

      it 'returns empty string for empty input' do
        result = masking_helper.send(:mask_email_value, '', 'standard')
        expect(result).to eq('')
      end
    end
  end

  describe '#mask_phone_value' do
    context 'with minimal pattern' do
      it 'masks phone showing country code and last 4 digits' do
        result = masking_helper.send(:mask_phone_value, '+1-555-123-4567', 'minimal')
        expect(result).to eq('+1 ***-***-4567')
      end

      it 'handles non-US numbers' do
        result = masking_helper.send(:mask_phone_value, '+44-20-1234-5678', 'minimal')
        expect(result).to eq('+** ***-***-5678')
      end
    end

    context 'with standard pattern' do
      it 'masks phone showing last 4 digits' do
        result = masking_helper.send(:mask_phone_value, '555-123-4567', 'standard')
        expect(result).to eq('***-***-4567')
      end

      it 'handles phone with country code' do
        result = masking_helper.send(:mask_phone_value, '+1 555 123 4567', 'standard')
        expect(result).to eq('***-***-4567')
      end
    end

    context 'with complete pattern' do
      it 'completely hides the phone' do
        result = masking_helper.send(:mask_phone_value, '+1-555-123-4567', 'complete')
        expect(result).to eq('*** HIDDEN ***')
      end
    end

    context 'with short phone numbers' do
      it 'handles short numbers gracefully' do
        result = masking_helper.send(:mask_phone_value, '1234', 'standard')
        expect(result).to eq('***')
      end

      it 'handles very short numbers' do
        result = masking_helper.send(:mask_phone_value, '12', 'standard')
        expect(result).to eq('***')
      end
    end

    context 'with invalid input' do
      it 'returns nil for nil input' do
        result = masking_helper.send(:mask_phone_value, nil, 'standard')
        expect(result).to be_nil
      end

      it 'returns original for non-numeric input' do
        result = masking_helper.send(:mask_phone_value, 'not-a-phone', 'standard')
        expect(result).to eq('not-a-phone')
      end
    end
  end

  describe '#should_mask_for_user?' do
    let(:user) { create(:user) }
    let(:admin_user) { create(:user, type: 'administrator') }
    let(:account) { create(:account) }

    context 'when masking is disabled' do
      before do
        allow(account).to receive(:masking_enabled?).and_return(false)
      end

      it 'returns false' do
        result = masking_helper.send(:should_mask_for_user?, user, account, 'email')
        expect(result).to be false
      end
    end

    context 'when masking is enabled' do
      before do
        allow(account).to receive(:masking_enabled?).and_return(true)
        allow(account).to receive(:masking_enabled_for?).with('email').and_return(true)
      end

      context 'for admin user with bypass enabled' do
        before do
          allow(account).to receive(:user_can_bypass_masking?).with(admin_user).and_return(true)
        end

        it 'returns false (no masking for admin)' do
          result = masking_helper.send(:should_mask_for_user?, admin_user, account, 'email')
          expect(result).to be false
        end
      end

      context 'for regular user' do
        before do
          allow(account).to receive(:user_can_bypass_masking?).with(user).and_return(false)
        end

        it 'returns true (should mask)' do
          result = masking_helper.send(:should_mask_for_user?, user, account, 'email')
          expect(result).to be true
        end
      end
    end
  end

  describe '#mask_domain' do
    it 'masks multi-part domains while keeping TLD' do
      result = masking_helper.send(:mask_domain, 'subdomain.example.com')
      expect(result).to eq('s***.e***.com')
    end

    it 'masks short domain parts' do
      result = masking_helper.send(:mask_domain, 'abc.co')
      expect(result).to eq('***.co')
    end

    it 'handles single domain' do
      result = masking_helper.send(:mask_domain, 'localhost')
      expect(result).to eq('localhost')
    end
  end
end