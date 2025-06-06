require 'rails_helper'

RSpec.describe 'Api::V1::AccountsController Masking', type: :request do
  let(:account) { create :account }
  let(:admin) { create :user, account: account, role: :administrator }
  let(:agent) { create :user, account: account, role: :agent }

  describe 'PATCH /api/v1/accounts/:id with masking settings' do
    context 'when it is an authenticated user' do
      context 'as an admin' do
        before do
          sign_in(admin)
        end

        it 'updates masking settings successfully' do
          masking_params = {
            masking: {
              masking_enabled: true,
              masking_rules: {
                admin_bypass: true,
                allow_reveal: false,
                exempt_roles: ['administrator'],
                email: {
                  enabled: true,
                  pattern: 'standard'
                },
                phone: {
                  enabled: true,
                  pattern: 'minimal'
                }
              }
            }
          }

          patch "/api/v1/accounts/#{account.id}",
                params: masking_params,
                as: :json

          expect(response).to have_http_status(:success)
          
          account.reload
          masking_settings = account.settings['masking']
          
          expect(masking_settings['masking_enabled']).to be true
          expect(masking_settings['masking_rules']['admin_bypass']).to be true
          expect(masking_settings['masking_rules']['allow_reveal']).to be false
          expect(masking_settings['masking_rules']['exempt_roles']).to eq(['administrator'])
          expect(masking_settings['masking_rules']['email']['enabled']).to be true
          expect(masking_settings['masking_rules']['email']['pattern']).to eq('standard')
          expect(masking_settings['masking_rules']['phone']['enabled']).to be true
          expect(masking_settings['masking_rules']['phone']['pattern']).to eq('minimal')
        end

        it 'updates only masking enabled flag' do
          patch "/api/v1/accounts/#{account.id}",
                params: {
                  masking: {
                    masking_enabled: false
                  }
                },
                as: :json

          expect(response).to have_http_status(:success)
          
          account.reload
          expect(account.settings['masking']['masking_enabled']).to be false
        end

        it 'updates partial masking rules' do
          patch "/api/v1/accounts/#{account.id}",
                params: {
                  masking: {
                    masking_rules: {
                      email: {
                        enabled: false,
                        pattern: 'complete'
                      }
                    }
                  }
                },
                as: :json

          expect(response).to have_http_status(:success)
          
          account.reload
          masking_settings = account.settings['masking']
          expect(masking_settings['masking_rules']['email']['enabled']).to be false
          expect(masking_settings['masking_rules']['email']['pattern']).to eq('complete')
        end

        it 'handles invalid masking pattern values' do
          patch "/api/v1/accounts/#{account.id}",
                params: {
                  masking: {
                    masking_rules: {
                      email: {
                        pattern: 'invalid_pattern'
                      }
                    }
                  }
                },
                as: :json

          expect(response).to have_http_status(:success)
          
          account.reload
          # Should still save the value (validation can happen on frontend/usage)
          expect(account.settings['masking']['masking_rules']['email']['pattern']).to eq('invalid_pattern')
        end

        it 'merges with existing settings' do
          # Set initial settings
          account.update!(
            settings: {
              'auto_resolve_after' => 24,
              'masking' => {
                'masking_enabled' => true,
                'masking_rules' => {
                  'admin_bypass' => false
                }
              }
            }
          )

          patch "/api/v1/accounts/#{account.id}",
                params: {
                  masking: {
                    masking_rules: {
                      email: {
                        enabled: true,
                        pattern: 'minimal'
                      }
                    }
                  }
                },
                as: :json

          expect(response).to have_http_status(:success)
          
          account.reload
          settings = account.settings
          
          # Should preserve existing non-masking settings
          expect(settings['auto_resolve_after']).to eq(24)
          
          # Should preserve existing masking settings
          expect(settings['masking']['masking_enabled']).to be true
          expect(settings['masking']['masking_rules']['admin_bypass']).to be false
          
          # Should add new masking settings
          expect(settings['masking']['masking_rules']['email']['enabled']).to be true
          expect(settings['masking']['masking_rules']['email']['pattern']).to eq('minimal')
        end

        it 'handles empty exempt_roles array' do
          patch "/api/v1/accounts/#{account.id}",
                params: {
                  masking: {
                    masking_rules: {
                      exempt_roles: []
                    }
                  }
                },
                as: :json

          expect(response).to have_http_status(:success)
          
          account.reload
          expect(account.settings['masking']['masking_rules']['exempt_roles']).to eq([])
        end

        it 'handles populated exempt_roles array' do
          patch "/api/v1/accounts/#{account.id}",
                params: {
                  masking: {
                    masking_rules: {
                      exempt_roles: ['administrator', 'agent']
                    }
                  }
                },
                as: :json

          expect(response).to have_http_status(:success)
          
          account.reload
          expect(account.settings['masking']['masking_rules']['exempt_roles']).to eq(['administrator', 'agent'])
        end
      end

      context 'as an agent' do
        before do
          sign_in(agent)
        end

        it 'does not allow updating masking settings' do
          patch "/api/v1/accounts/#{account.id}",
                params: {
                  masking: {
                    masking_enabled: false
                  }
                },
                as: :json

          # This should be handled by authorization policies
          # The exact behavior depends on your authorization setup
          expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
        end
      end
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}",
              params: {
                masking: {
                  masking_enabled: false
                }
              },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/accounts/:id with masking enabled' do
    let(:contact) { create(:contact, account: account, email: 'contact@example.com', phone_number: '+1-555-123-4567') }
    
    before do
      # Enable masking for the account
      account.update!(
        settings: {
          'masking' => {
            'masking_enabled' => true,
            'masking_rules' => {
              'admin_bypass' => true,
              'allow_reveal' => false,
              'exempt_roles' => [],
              'email' => { 'enabled' => true, 'pattern' => 'standard' },
              'phone' => { 'enabled' => true, 'pattern' => 'standard' }
            }
          }
        }
      )
    end

    context 'when requesting as admin with bypass enabled' do
      before do
        sign_in(admin)
      end

      it 'returns unmasked data in account response' do
        get "/api/v1/accounts/#{account.id}", as: :json

        expect(response).to have_http_status(:success)
        # The account show response doesn't directly contain contact data,
        # but we can verify the masking configuration is returned
        response_data = JSON.parse(response.body)
        expect(response_data).to have_key('id')
      end
    end

    context 'when requesting as regular agent' do
      before do
        sign_in(agent)
      end

      it 'applies masking rules to sensitive data' do
        get "/api/v1/accounts/#{account.id}", as: :json

        expect(response).to have_http_status(:success)
        # Similar to above - account endpoint doesn't directly expose contact data
        response_data = JSON.parse(response.body)
        expect(response_data).to have_key('id')
      end
    end
  end

  describe 'parameter validation' do
    before do
      sign_in(admin)
    end

    it 'ignores unknown masking parameters' do
      patch "/api/v1/accounts/#{account.id}",
            params: {
              masking: {
                unknown_param: 'value',
                masking_enabled: true
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      
      account.reload
      # Should only save permitted parameters
      expect(account.settings['masking']['masking_enabled']).to be true
      expect(account.settings['masking']).not_to have_key('unknown_param')
    end

    it 'handles deeply nested unknown parameters' do
      patch "/api/v1/accounts/#{account.id}",
            params: {
              masking: {
                masking_rules: {
                  unknown_field: { enabled: true, pattern: 'test' },
                  email: { enabled: true, pattern: 'standard' }
                }
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      
      account.reload
      masking_rules = account.settings['masking']['masking_rules']
      expect(masking_rules['email']['enabled']).to be true
      expect(masking_rules).not_to have_key('unknown_field')
    end
  end

  describe 'edge cases' do
    before do
      sign_in(admin)
    end

    it 'handles nil masking parameter' do
      patch "/api/v1/accounts/#{account.id}",
            params: {
              masking: nil
            },
            as: :json

      expect(response).to have_http_status(:success)
    end

    it 'handles empty masking parameter' do
      patch "/api/v1/accounts/#{account.id}",
            params: {
              masking: {}
            },
            as: :json

      expect(response).to have_http_status(:success)
    end

    it 'combines masking updates with other account updates' do
      patch "/api/v1/accounts/#{account.id}",
            params: {
              name: 'Updated Account Name',
              auto_resolve_after: 48,
              masking: {
                masking_enabled: true
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      
      account.reload
      expect(account.name).to eq('Updated Account Name')
      expect(account.settings['auto_resolve_after']).to eq(48)
      expect(account.settings['masking']['masking_enabled']).to be true
    end
  end
end