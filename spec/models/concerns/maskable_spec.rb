require 'rails_helper'

RSpec.describe Maskable, type: :concern do
  let(:maskable_class) do
    Class.new do
      include Maskable
    end
  end
  let(:maskable_instance) { maskable_class.new }
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, type: 'administrator') }
  let(:account) { create(:account) }

  before do
    # Set up default account settings (masking enabled by default, no admin bypass)
    account.update!(
      settings: {
        'masking' => {
          'masking_enabled' => true,
          'masking_rules' => {
            'admin_bypass' => false,  # Don't bypass for admins by default
            'allow_reveal' => false,
            'exempt_roles' => [],
            'email' => { 'enabled' => true, 'pattern' => 'standard' },
            'phone' => { 'enabled' => true, 'pattern' => 'standard' }
          }
        }
      }
    )
  end

  describe '#mask_email_for_user' do
    context 'when masking is disabled' do
      before do
        account.settings['masking']['masking_enabled'] = false
        account.save!
      end

      it 'returns original email' do
        result = maskable_instance.mask_email_for_user('john.doe@example.com', user, account)
        expect(result).to eq('john.doe@example.com')
      end
    end

    context 'when masking is enabled' do
      context 'for admin user with bypass enabled' do
        before do
          account.settings['masking']['masking_rules']['admin_bypass'] = true
          account.save!
        end

        it 'returns original email' do
          result = maskable_instance.mask_email_for_user('john.doe@example.com', admin_user, account)
          expect(result).to eq('john.doe@example.com')
        end
      end

      context 'for admin user without bypass (default)' do
        it 'masks email like regular users' do
          result = maskable_instance.mask_email_for_user('john.doe@example.com', admin_user, account)
          expect(result).to eq('j***e@e***.com')
        end
      end

      context 'for exempt role user' do
        before do
          account.settings['masking']['masking_rules']['exempt_roles'] = ['agent']
          account.save!
          user.account_users.first.update!(role: 'agent')
        end

        it 'returns original email' do
          result = maskable_instance.mask_email_for_user('john.doe@example.com', user, account)
          expect(result).to eq('john.doe@example.com')
        end
      end

      context 'for regular user' do
        it 'masks email with standard pattern' do
          result = maskable_instance.mask_email_for_user('john.doe@example.com', user, account)
          expect(result).to eq('j***e@e***.com')
        end

        it 'masks email with minimal pattern' do
          account.settings['masking']['masking_rules']['email']['pattern'] = 'minimal'
          account.save!
          
          result = maskable_instance.mask_email_for_user('john.doe@example.com', user, account)
          expect(result).to eq('j***@example.com')
        end

        it 'completely hides email with complete pattern' do
          account.settings['masking']['masking_rules']['email']['pattern'] = 'complete'
          account.save!
          
          result = maskable_instance.mask_email_for_user('john.doe@example.com', user, account)
          expect(result).to eq('*** HIDDEN ***')
        end
      end

      context 'when email masking is disabled specifically' do
        before do
          account.settings['masking']['masking_rules']['email']['enabled'] = false
          account.save!
        end

        it 'returns original email' do
          result = maskable_instance.mask_email_for_user('john.doe@example.com', user, account)
          expect(result).to eq('john.doe@example.com')
        end
      end
    end

    context 'with invalid inputs' do
      it 'handles nil email' do
        result = maskable_instance.mask_email_for_user(nil, user, account)
        expect(result).to be_nil
      end

      it 'handles empty email' do
        result = maskable_instance.mask_email_for_user('', user, account)
        expect(result).to eq('')
      end

      it 'handles invalid email format' do
        result = maskable_instance.mask_email_for_user('invalid-email', user, account)
        expect(result).to eq('invalid-email')
      end
    end
  end

  describe '#mask_phone_for_user' do
    context 'when masking is disabled' do
      before do
        account.settings['masking']['masking_enabled'] = false
        account.save!
      end

      it 'returns original phone' do
        result = maskable_instance.mask_phone_for_user('+1-555-123-4567', user, account)
        expect(result).to eq('+1-555-123-4567')
      end
    end

    context 'when masking is enabled' do
      context 'for admin user with bypass enabled' do
        before do
          account.settings['masking']['masking_rules']['admin_bypass'] = true
          account.save!
        end

        it 'returns original phone' do
          result = maskable_instance.mask_phone_for_user('+1-555-123-4567', admin_user, account)
          expect(result).to eq('+1-555-123-4567')
        end
      end

      context 'for admin user without bypass (default)' do
        it 'masks phone like regular users' do
          result = maskable_instance.mask_phone_for_user('555-123-4567', admin_user, account)
          expect(result).to eq('***-***-4567')
        end
      end

      context 'for regular user' do
        it 'masks phone with standard pattern' do
          result = maskable_instance.mask_phone_for_user('555-123-4567', user, account)
          expect(result).to eq('***-***-4567')
        end

        it 'masks phone with minimal pattern' do
          account.settings['masking']['masking_rules']['phone']['pattern'] = 'minimal'
          account.save!
          
          result = maskable_instance.mask_phone_for_user('+1-555-123-4567', user, account)
          expect(result).to eq('+1 ***-***-4567')
        end

        it 'completely hides phone with complete pattern' do
          account.settings['masking']['masking_rules']['phone']['pattern'] = 'complete'
          account.save!
          
          result = maskable_instance.mask_phone_for_user('+1-555-123-4567', user, account)
          expect(result).to eq('*** HIDDEN ***')
        end
      end

      context 'when phone masking is disabled specifically' do
        before do
          account.settings['masking']['masking_rules']['phone']['enabled'] = false
          account.save!
        end

        it 'returns original phone' do
          result = maskable_instance.mask_phone_for_user('+1-555-123-4567', user, account)
          expect(result).to eq('+1-555-123-4567')
        end
      end
    end

    context 'with invalid inputs' do
      it 'handles nil phone' do
        result = maskable_instance.mask_phone_for_user(nil, user, account)
        expect(result).to be_nil
      end

      it 'handles empty phone' do
        result = maskable_instance.mask_phone_for_user('', user, account)
        expect(result).to eq('')
      end

      it 'handles non-numeric phone' do
        result = maskable_instance.mask_phone_for_user('not-a-phone', user, account)
        expect(result).to eq('not-a-phone')
      end
    end
  end

  describe 'Account model integration' do
    describe '#masking_enabled?' do
      it 'returns true when masking is enabled' do
        expect(account.masking_enabled?).to be true
      end

      it 'returns false when masking is explicitly disabled' do
        account.settings['masking']['masking_enabled'] = false
        account.save!
        expect(account.masking_enabled?).to be false
      end

      it 'returns true when masking config is missing (default enabled)' do
        account.update!(settings: {})
        expect(account.masking_enabled?).to be true
      end
    end

    describe '#masking_enabled_for?' do
      it 'returns true for enabled email masking' do
        expect(account.masking_enabled_for?('email')).to be true
      end

      it 'returns true for enabled phone masking' do
        expect(account.masking_enabled_for?('phone')).to be true
      end

      it 'returns false for disabled email masking' do
        account.settings['masking']['masking_rules']['email']['enabled'] = false
        account.save!
        expect(account.masking_enabled_for?('email')).to be false
      end

      it 'returns false for unknown field type' do
        expect(account.masking_enabled_for?('unknown')).to be false
      end
    end

    describe '#user_can_bypass_masking?' do
      it 'returns false for admin when bypass is disabled (default)' do
        expect(account.user_can_bypass_masking?(admin_user)).to be false
      end

      it 'returns true for admin when bypass is explicitly enabled' do
        account.settings['masking']['masking_rules']['admin_bypass'] = true
        account.save!
        expect(account.user_can_bypass_masking?(admin_user)).to be true
      end

      it 'returns true for user with exempt role' do
        account.settings['masking']['masking_rules']['exempt_roles'] = ['agent']
        account.save!
        user.account_users.first.update!(role: 'agent')
        expect(account.user_can_bypass_masking?(user)).to be true
      end

      it 'returns false for regular user' do
        expect(account.user_can_bypass_masking?(user)).to be false
      end

      it 'handles nil user gracefully' do
        expect(account.user_can_bypass_masking?(nil)).to be false
      end
    end

    describe '#masking_pattern_for' do
      it 'returns email pattern' do
        expect(account.masking_pattern_for('email')).to eq('standard')
      end

      it 'returns phone pattern' do
        expect(account.masking_pattern_for('phone')).to eq('standard')
      end

      it 'returns standard as default for unknown field' do
        expect(account.masking_pattern_for('unknown')).to eq('standard')
      end

      it 'handles custom patterns' do
        account.settings['masking']['masking_rules']['email']['pattern'] = 'minimal'
        account.save!
        expect(account.masking_pattern_for('email')).to eq('minimal')
      end
    end
  end

  describe 'error handling and edge cases' do
    it 'handles missing account settings gracefully' do
      account.update!(settings: nil)
      result = maskable_instance.mask_email_for_user('test@example.com', user, account)
      expect(result).to eq('test@example.com')
    end

    it 'handles malformed masking configuration' do
      account.update!(settings: { 'masking' => 'invalid' })
      result = maskable_instance.mask_email_for_user('test@example.com', user, account)
      expect(result).to eq('test@example.com')
    end

    it 'handles missing user account relationship' do
      user_without_account = create(:user)
      result = maskable_instance.mask_email_for_user('test@example.com', user_without_account, account)
      expect(result).to eq('t***t@e***.com') # Should still mask
    end

    it 'handles invalid masking patterns gracefully' do
      account.settings['masking']['masking_rules']['email']['pattern'] = 'invalid'
      account.save!
      
      result = maskable_instance.mask_email_for_user('test@example.com', user, account)
      expect(result).to eq('t***t@e***.com') # Should fallback to standard
    end
  end
end