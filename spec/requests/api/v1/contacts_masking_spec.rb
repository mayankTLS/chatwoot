require 'rails_helper'

RSpec.describe 'Api::V1::Contacts Masking Integration', type: :request do
  let(:account) { create :account }
  let(:admin) { create :user, account: account, role: :administrator }
  let(:agent) { create :user, account: account, role: :agent }
  let(:contact) { create(:contact, account: account, email: 'john.doe@example.com', phone_number: '+1-555-123-4567') }
  let(:inbox) { create(:inbox, account: account) }

  before do
    # Set up masking configuration (enabled by default, no admin bypass)
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

  describe 'GET /api/v1/accounts/:account_id/contacts' do
    context 'when requesting as admin with bypass enabled' do
      before do
        account.settings['masking']['masking_rules']['admin_bypass'] = true
        account.save!
        sign_in(admin)
        contact # Create the contact
      end

      it 'returns unmasked contact data' do
        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('john.doe@example.com')
        expect(contact_data['phone_number']).to eq('+1-555-123-4567')
      end
    end

    context 'when requesting as admin without bypass (default)' do
      before do
        sign_in(admin)
        contact # Create the contact
      end

      it 'returns masked contact data' do
        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('j***e@e***.com')
        expect(contact_data['phone_number']).to eq('***-***-4567')
      end
    end

    context 'when requesting as regular agent' do
      before do
        sign_in(agent)
        contact # Create the contact
      end

      it 'returns masked contact data' do
        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('j***e@e***.com')
        expect(contact_data['phone_number']).to eq('***-***-4567')
      end
    end

    context 'when masking is disabled' do
      before do
        account.settings['masking']['masking_enabled'] = false
        account.save!
        sign_in(agent)
        contact # Create the contact
      end

      it 'returns unmasked contact data' do
        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('john.doe@example.com')
        expect(contact_data['phone_number']).to eq('+1-555-123-4567')
      end
    end

    context 'when agent role is exempt' do
      before do
        account.settings['masking']['masking_rules']['exempt_roles'] = ['agent']
        account.save!
        sign_in(agent)
        contact # Create the contact
      end

      it 'returns unmasked contact data' do
        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('john.doe@example.com')
        expect(contact_data['phone_number']).to eq('+1-555-123-4567')
      end
    end

    context 'with different masking patterns' do
      before do
        sign_in(agent)
        contact # Create the contact
      end

      it 'applies minimal pattern correctly' do
        account.settings['masking']['masking_rules']['email']['pattern'] = 'minimal'
        account.settings['masking']['masking_rules']['phone']['pattern'] = 'minimal'
        account.save!

        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('j***@example.com')
        expect(contact_data['phone_number']).to eq('+1 ***-***-4567')
      end

      it 'applies complete pattern correctly' do
        account.settings['masking']['masking_rules']['email']['pattern'] = 'complete'
        account.settings['masking']['masking_rules']['phone']['pattern'] = 'complete'
        account.save!

        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('*** HIDDEN ***')
        expect(contact_data['phone_number']).to eq('*** HIDDEN ***')
      end
    end

    context 'when specific field masking is disabled' do
      before do
        account.settings['masking']['masking_rules']['email']['enabled'] = false
        account.save!
        sign_in(agent)
        contact # Create the contact
      end

      it 'masks only enabled fields' do
        get "/api/v1/accounts/#{account.id}/contacts", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        contact_data = response_data['payload'].first

        expect(contact_data['email']).to eq('john.doe@example.com') # Not masked
        expect(contact_data['phone_number']).to eq('***-***-4567') # Still masked
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/contacts/:id' do
    before do
      contact # Create the contact
    end

    context 'when requesting as admin' do
      before do
        sign_in(admin)
      end

      it 'returns unmasked contact data' do
        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)

        expect(response_data['payload']['contact']['email']).to eq('john.doe@example.com')
        expect(response_data['payload']['contact']['phone_number']).to eq('+1-555-123-4567')
      end
    end

    context 'when requesting as regular agent' do
      before do
        sign_in(agent)
      end

      it 'returns masked contact data' do
        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}", as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)

        expect(response_data['payload']['contact']['email']).to eq('j***e@e***.com')
        expect(response_data['payload']['contact']['phone_number']).to eq('***-***-4567')
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/contacts search' do
    before do
      contact # Create the contact
    end

    context 'when requesting as admin' do
      before do
        sign_in(admin)
      end

      it 'returns unmasked contact data in search results' do
        post "/api/v1/accounts/#{account.id}/contacts/search",
             params: { q: 'john' },
             as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        
        if response_data['payload'].any?
          contact_data = response_data['payload'].first
          expect(contact_data['email']).to eq('john.doe@example.com')
          expect(contact_data['phone_number']).to eq('+1-555-123-4567')
        end
      end
    end

    context 'when requesting as regular agent' do
      before do
        sign_in(agent)
      end

      it 'returns masked contact data in search results' do
        post "/api/v1/accounts/#{account.id}/contacts/search",
             params: { q: 'john' },
             as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body)
        
        if response_data['payload'].any?
          contact_data = response_data['payload'].first
          expect(contact_data['email']).to eq('j***e@e***.com')
          expect(contact_data['phone_number']).to eq('***-***-4567')
        end
      end
    end
  end

  describe 'edge cases and error handling' do
    before do
      sign_in(agent)
    end

    it 'handles contacts with nil email and phone' do
      contact_without_info = create(:contact, account: account, email: nil, phone_number: nil)

      get "/api/v1/accounts/#{account.id}/contacts", as: :json

      expect(response).to have_http_status(:success)
      response_data = JSON.parse(response.body)
      
      contact_data = response_data['payload'].find { |c| c['id'] == contact_without_info.id }
      expect(contact_data['email']).to be_nil
      expect(contact_data['phone_number']).to be_nil
    end

    it 'handles contacts with empty email and phone' do
      contact_with_empty = create(:contact, account: account, email: '', phone_number: '')

      get "/api/v1/accounts/#{account.id}/contacts", as: :json

      expect(response).to have_http_status(:success)
      response_data = JSON.parse(response.body)
      
      contact_data = response_data['payload'].find { |c| c['id'] == contact_with_empty.id }
      expect(contact_data['email']).to eq('')
      expect(contact_data['phone_number']).to eq('')
    end

    it 'handles invalid email formats gracefully' do
      contact_invalid = create(:contact, account: account, email: 'invalid-email', phone_number: 'not-a-phone')

      get "/api/v1/accounts/#{account.id}/contacts", as: :json

      expect(response).to have_http_status(:success)
      response_data = JSON.parse(response.body)
      
      contact_data = response_data['payload'].find { |c| c['id'] == contact_invalid.id }
      expect(contact_data['email']).to eq('invalid-email') # Should return as-is for invalid formats
      expect(contact_data['phone_number']).to eq('not-a-phone') # Should return as-is for invalid formats
    end

    it 'handles missing masking configuration gracefully' do
      account.update!(settings: {})
      contact # Create the contact

      get "/api/v1/accounts/#{account.id}/contacts", as: :json

      expect(response).to have_http_status(:success)
      response_data = JSON.parse(response.body)
      contact_data = response_data['payload'].first

      # Should return unmasked data when no masking config
      expect(contact_data['email']).to eq('john.doe@example.com')
      expect(contact_data['phone_number']).to eq('+1-555-123-4567')
    end
  end
end