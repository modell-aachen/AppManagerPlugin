/* global $ Vue */
import AppList from './components/AppList.vue';

$( function () {
    Vue.instantiateEach(
        '.AppManagerContainer',
         { components: { appList: AppList } }
    );
});
