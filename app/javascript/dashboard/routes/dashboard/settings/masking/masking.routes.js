import { FEATURE_FLAGS } from '../../../../featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { frontendURL } from '../../../../helper/URLHelper';

const MaskingWrapper = () => import('../SettingsWrapper.vue');
const MaskingIndex = () => import('./Index.vue');

const meta = {
  featureFlag: FEATURE_FLAGS.DATA_MASKING,
  permissions: ['administrator'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/masking'),
      component: MaskingWrapper,
      children: [
        {
          path: '',
          name: 'masking_settings_index',
          component: MaskingIndex,
          meta,
        },
      ],
    },
  ],
};